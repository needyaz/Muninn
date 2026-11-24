/**
 * Mac App Store screenshots, per locale, from the folders under listing/screenshots/<locale>/ (`make screenshots`
 * renders them). Files are shown in file-name order (01_…, 02_…).
 *
 *   deno run --allow-read scripts/listing_screenshots.ts check     offline: sizes, count, formats
 *   deno run --allow-net --allow-env --allow-read scripts/listing_screenshots.ts dump
 *   deno run --allow-net --allow-env --allow-read scripts/listing_screenshots.ts diff
 *   deno run --allow-net --allow-env --allow-read scripts/listing_screenshots.ts apply
 *   deno run --allow-net --allow-env --allow-read scripts/listing_screenshots.ts carry [--dry-run]
 *
 * `carry` is for locales the repo has no screenshots for: it copies every screenshot set of the live (READY_FOR_SALE)
 * version into the editable version (same display types, same order), skipping sets the editable version already has.
 * Screenshots belong to a version's localization, so they can only change while a version is editable and the locale
 * already exists (run listing_metadata.ts apply first). Order is set by upload order, so any difference replaces the
 * whole set for that locale. A locale with no local PNGs is never touched: its live screenshots are left as they are.
 *
 * Needs ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_FILEPATH (build box only).
 */

import { createHash } from "node:crypto";
import { asc, ascJwt, EDITABLE_STATES, fail, findApp, type Json, macVersions, pass, pickTarget, step } from "./lib/asc.ts";

export const LIVE_STATE = "READY_FOR_SALE";

const SHOTS_DIR = new URL("../listing/screenshots/", import.meta.url).pathname;

// ---------------------------------------------------------------------------
// Pure logic (tested in listing_screenshots_test.ts)
// ---------------------------------------------------------------------------

export interface LocalShot { fileName: string; md5: string; size: number; path: string }
export interface LiveShot { id: string; fileName: string; md5: string; state: string }
export type SetPlan = { action: "match" } | { action: "replace"; deleteIds: string[]; upload: string[] };

export const DISPLAY_TYPE = "APP_DESKTOP";
export const MAX_PER_SET = 10;
/** The sizes the Mac App Store accepts (all 16:10). */
export const MAC_SIZES = [[1280, 800], [1440, 900], [2560, 1600], [2880, 1800]];

export const isMacSize = (width: number, height: number) => MAC_SIZES.some(([w, h]) => w === width && h === height);

/** `local` and `live` are both in display order. */
export function planScreenshotSet(local: LocalShot[], live: LiveShot[]): SetPlan {
  const same = local.length === live.length &&
    local.every((l, i) => live[i].state === "COMPLETE" && live[i].md5 === l.md5 && live[i].fileName === l.fileName);
  if (same) return { action: "match" };
  return { action: "replace", deleteIds: live.map((s) => s.id), upload: local.map((s) => s.fileName) };
}

/** Width and height from a PNG header or a JPEG start-of-frame marker. */
export function imageSize(bytes: Uint8Array): { w: number; h: number } | null {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  if (bytes.length > 24 && bytes[0] === 0x89 && bytes[1] === 0x50) return { w: view.getUint32(16), h: view.getUint32(20) };
  if (bytes[0] === 0xff && bytes[1] === 0xd8) {
    let offset = 2;
    while (offset + 9 < bytes.length) {
      if (bytes[offset] !== 0xff) return null;
      const marker = bytes[offset + 1];
      if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
        return { h: view.getUint16(offset + 5), w: view.getUint16(offset + 7) };
      }
      offset += 2 + view.getUint16(offset + 2);
    }
  }
  return null;
}

/** Problems with one locale's folder: a size Apple rejects, mixed sizes in a set, or too many images. */
export function validateSet(locale: string, shots: { fileName: string; w: number; h: number }[]): string[] {
  const problems: string[] = [];
  if (shots.length > MAX_PER_SET) problems.push(`${locale}: ${shots.length} screenshots; Apple allows at most ${MAX_PER_SET}`);
  for (const s of shots) {
    if (!isMacSize(s.w, s.h)) problems.push(`${locale}/${s.fileName}: ${s.w}×${s.h} is not a Mac App Store size (${MAC_SIZES.map(([w, h]) => `${w}×${h}`).join(", ")})`);
  }
  if (new Set(shots.map((s) => `${s.w}x${s.h}`)).size > 1) problems.push(`${locale}: mixed sizes in one set`);
  return problems;
}

// ---------------------------------------------------------------------------
// Carrying the live version's screenshots over to the editable version
// ---------------------------------------------------------------------------

export interface CarryShot { fileName: string; downloadUrl: string }
export interface CarrySet { displayType: string; shots: CarryShot[] }

/** The live sets the editable version does not have yet (a set with at least one screenshot counts as had). */
export function planCarry(live: CarrySet[], editable: { displayType: string; count: number }[]): CarrySet[] {
  const have = new Set(editable.filter((s) => s.count > 0).map((s) => s.displayType));
  return live.filter((s) => s.shots.length > 0 && !have.has(s.displayType));
}

/** Locales to carry: those of the live version that the repo has no screenshots for and the editable version has. */
export function carryLocales(liveLocales: string[], editableLocales: string[], localLocales: string[]): string[] {
  return liveLocales.filter((l) => editableLocales.includes(l) && !localLocales.includes(l)).sort();
}

/** The download URL of a screenshot's image asset (the template takes width, height and format). */
export function assetUrl(asset: { templateUrl?: string; width?: number; height?: number } | undefined): string {
  if (!asset?.templateUrl) return "";
  return asset.templateUrl.replace("{w}", String(asset.width ?? "")).replace("{h}", String(asset.height ?? "")).replace("{f}", "png");
}

export interface CarryApi {
  asc: (path: string, init?: RequestInit) => Promise<Json>;
  fetch: (url: string, init?: RequestInit) => Promise<Response>;
  log?: (message: string) => void;
}

async function readSets(api: CarryApi, localizationId: string): Promise<{ id: string; displayType: string; shots: CarryShot[] }[]> {
  const sets = await api.asc(`/appStoreVersionLocalizations/${localizationId}/appScreenshotSets?limit=50`);
  const out = [];
  for (const set of sets.data) {
    const list = await api.asc(`/appScreenshotSets/${set.id}/appScreenshots?limit=50`);
    out.push({
      id: set.id,
      displayType: set.attributes.screenshotDisplayType,
      shots: list.data.map((x: Json) => ({ fileName: x.attributes.fileName, downloadUrl: assetUrl(x.attributes.imageAsset) })),
    });
  }
  return out;
}

/** Copies the missing sets of one locale from the live localization to the editable one; returns what was (or would be) copied. */
export async function carryLocale(
  api: CarryApi,
  locale: string,
  liveLocalizationId: string,
  editableLocalizationId: string,
  dry: boolean,
): Promise<{ displayType: string; count: number }[]> {
  const log = api.log ?? (() => {});
  const liveSets = await readSets(api, liveLocalizationId);
  const have = (await readSets(api, editableLocalizationId)).map((s) => ({ displayType: s.displayType, count: s.shots.length }));
  const copied: { displayType: string; count: number }[] = [];
  for (const set of planCarry(liveSets, have)) {
    copied.push({ displayType: set.displayType, count: set.shots.length });
    if (dry) { log(`  [${locale}] would copy ${set.shots.length} ${set.displayType} screenshot(s)`); continue; }
    const existing = (await readSets(api, editableLocalizationId)).find((s) => s.displayType === set.displayType);
    const setId = existing?.id ?? (await api.asc(`/appScreenshotSets`, {
      method: "POST",
      body: JSON.stringify({ data: {
        type: "appScreenshotSets",
        attributes: { screenshotDisplayType: set.displayType },
        relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: editableLocalizationId } } },
      } }),
    })).data.id;
    for (const shot of set.shots) {
      log(`  [${locale}] copying ${set.displayType} ${shot.fileName}`);
      const download = await api.fetch(shot.downloadUrl);
      if (!download.ok) throw new Error(`download ${shot.fileName} → ${download.status}`);
      const bytes = new Uint8Array(await download.arrayBuffer());
      const reservation = await api.asc(`/appScreenshots`, {
        method: "POST",
        body: JSON.stringify({ data: {
          type: "appScreenshots",
          attributes: { fileName: shot.fileName, fileSize: bytes.length },
          relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: setId } } },
        } }),
      });
      for (const op of reservation.data.attributes.uploadOperations) {
        const response = await api.fetch(op.url, {
          method: op.method,
          headers: Object.fromEntries(op.requestHeaders.map((h: Json) => [h.name, h.value])),
          body: bytes.slice(op.offset, op.offset + op.length),
        });
        if (!response.ok) throw new Error(`upload part ${op.offset}+${op.length} → ${response.status}: ${await response.text()}`);
      }
      await api.asc(`/appScreenshots/${reservation.data.id}`, {
        method: "PATCH",
        body: JSON.stringify({ data: { type: "appScreenshots", id: reservation.data.id, attributes: { uploaded: true, sourceFileChecksum: createHash("md5").update(bytes).digest("hex") } } }),
      });
    }
  }
  return copied;
}

// ---------------------------------------------------------------------------
// Local folders
// ---------------------------------------------------------------------------

async function readLocal(): Promise<{ shots: Record<string, LocalShot[]>; problems: string[] }> {
  const shots: Record<string, LocalShot[]> = {};
  const problems: string[] = [];
  let locales: string[] = [];
  try {
    locales = [...Deno.readDirSync(SHOTS_DIR)].filter((e) => e.isDirectory).map((e) => e.name).sort();
  } catch { return { shots, problems: [`no screenshots folder at ${SHOTS_DIR}`] }; }
  for (const locale of locales) {
    const names = [...Deno.readDirSync(`${SHOTS_DIR}${locale}`)]
      .filter((e) => e.isFile && /\.(jpe?g|png)$/i.test(e.name)).map((e) => e.name).sort();
    if (names.length === 0) continue;
    const found: { fileName: string; w: number; h: number }[] = [];
    shots[locale] = [];
    for (const fileName of names) {
      const path = `${SHOTS_DIR}${locale}/${fileName}`;
      const bytes = await Deno.readFile(path);
      const size = imageSize(bytes);
      if (!size) { problems.push(`${locale}/${fileName}: not a readable PNG or JPEG`); continue; }
      found.push({ fileName, ...size });
      shots[locale].push({ fileName, path, size: bytes.length, md5: createHash("md5").update(bytes).digest("hex") });
    }
    problems.push(...validateSet(locale, found));
  }
  return { shots, problems };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

if (import.meta.main) {
  const command = Deno.args[0];
  if (!["check", "dump", "diff", "apply", "carry"].includes(command ?? "")) {
    console.error("usage: listing_screenshots.ts <check|dump|diff|apply|carry [--dry-run]>");
    Deno.exit(1);
  }
  const { shots: local, problems } = await readLocal();
  if (problems.length > 0) { problems.forEach(fail); Deno.exit(1); }
  const noneRendered = Object.keys(local).length === 0;
  if (command === "carry") {
    const dry = Deno.args.includes("--dry-run");
    const jwt = await ascJwt();
    const appId = await findApp(jwt);
    const versions = await macVersions(jwt, appId);
    const liveVersion = versions.find((v) => v.state === LIVE_STATE);
    const editableVersion = versions.find((v) => EDITABLE_STATES.has(v.state));
    if (!liveVersion) { pass(`No ${LIVE_STATE} version, so there is nothing to carry over.`); Deno.exit(0); }
    if (!editableVersion) { fail("Carrying screenshots needs an EDITABLE version and none exists. Nothing was changed."); Deno.exit(1); }
    const localizationsOf = async (id: string): Promise<Record<string, string>> =>
      Object.fromEntries((await asc(jwt, `/appStoreVersions/${id}/appStoreVersionLocalizations?limit=200`)).data.map((l: Json) => [l.attributes.locale, l.id]));
    const liveLoc = await localizationsOf(liveVersion.id);
    const editableLoc = await localizationsOf(editableVersion.id);
    const api: CarryApi = { asc: (path, init) => asc(jwt, path, init), fetch: (url, init) => fetch(url, init), log: (m) => console.log(m) };
    step(`${dry ? "Dry run: " : ""}carrying screenshots from ${liveVersion.versionString} to ${editableVersion.versionString}…`);
    let total = 0;
    for (const locale of carryLocales(Object.keys(liveLoc), Object.keys(editableLoc), Object.keys(local))) {
      total += (await carryLocale(api, locale, liveLoc[locale], editableLoc[locale], dry)).length;
    }
    pass(total === 0 ? "Nothing to carry over: the editable version already has the live version's screenshot sets." : `${dry ? "Would copy" : "Copied"} ${total} screenshot set(s).`);
    Deno.exit(0);
  }
  if (command === "check") {
    if (noneRendered) pass("no screenshots in listing/screenshots yet (not rendered: run make screenshots)");
    for (const [locale, list] of Object.entries(local)) pass(`${locale}: ${list.length} screenshot(s), all Mac App Store sizes`);
    Deno.exit(0);
  }
  if (noneRendered && command !== "dump") {
    pass("No local screenshots (not rendered yet), so the store's screenshots are left as they are.");
    Deno.exit(0);
  }

  const jwt = await ascJwt();
  step("Reading the App Store screenshot sets…");
  const appId = await findApp(jwt);
  const picked = pickTarget(await macVersions(jwt, appId));
  if (!picked) { fail("The app has no macOS version yet. Run listing_metadata.ts apply --create-version <string> first."); Deno.exit(1); }
  const { target, editable } = picked;
  pass(`version ${target.versionString} (${editable ? "editable" : `${target.state}, read-only`})`);

  const localizations = (await asc(jwt, `/appStoreVersions/${target.id}/appStoreVersionLocalizations`)).data;
  const locId: Record<string, string> = Object.fromEntries(localizations.map((l: Json) => [l.attributes.locale, l.id]));

  const readSet = async (localizationId: string): Promise<{ setId: string; shots: LiveShot[] } | undefined> => {
    const sets = await asc(jwt, `/appStoreVersionLocalizations/${localizationId}/appScreenshotSets?limit=50`);
    const set = sets.data.find((s: Json) => s.attributes.screenshotDisplayType === DISPLAY_TYPE);
    if (!set) return undefined;
    const list = await asc(jwt, `/appScreenshotSets/${set.id}/appScreenshots?limit=50`);
    return {
      setId: set.id,
      shots: list.data.map((x: Json) => ({
        id: x.id,
        fileName: x.attributes.fileName,
        md5: x.attributes.sourceFileChecksum ?? "",
        state: x.attributes.assetDeliveryState?.state ?? "",
      })),
    };
  };

  if (command === "dump") {
    for (const [locale, id] of Object.entries(locId)) {
      const set = await readSet(id);
      console.log(`  [${locale}] ${set ? `${set.shots.length} screenshot(s): ${set.shots.map((s) => `${s.fileName} (${s.state})`).join(", ")}` : "no Mac screenshot set"}`);
    }
    Deno.exit(0);
  }

  const work: { locale: string; setId?: string; plan: SetPlan; shots: LocalShot[] }[] = [];
  let pending = 0;
  for (const [locale, shots] of Object.entries(local)) {
    if (!locId[locale]) {
      if (command === "diff") { pending++; console.log(`  [${locale}] locale not on the store yet: would upload ${shots.length} after listing_metadata.ts apply creates it`); continue; }
      fail(`[${locale}] has a screenshots folder but no localization on this version. Run listing_metadata.ts apply first.`);
      Deno.exit(1);
    }
    const live = await readSet(locId[locale]);
    const plan = planScreenshotSet(shots, live?.shots ?? []);
    if (plan.action === "replace") { pending++; console.log(`  [${locale}] replace: delete ${plan.deleteIds.length}, upload ${plan.upload.length}`); }
    work.push({ locale, setId: live?.setId, plan, shots });
  }
  if (pending === 0) { pass("The store's screenshots already match listing/screenshots."); Deno.exit(0); }
  if (command === "diff") Deno.exit(1);
  if (!editable) { fail("Screenshots need an EDITABLE version and none exists. Nothing was changed."); Deno.exit(1); }

  for (const w of work) {
    if (w.plan.action !== "replace") continue;
    let setId = w.setId;
    if (!setId) {
      step(`Creating the screenshot set [${w.locale}]…`);
      setId = (await asc(jwt, `/appScreenshotSets`, {
        method: "POST",
        body: JSON.stringify({ data: {
          type: "appScreenshotSets",
          attributes: { screenshotDisplayType: DISPLAY_TYPE },
          relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: locId[w.locale] } } },
        } }),
      })).data.id;
    }
    for (const id of w.plan.deleteIds) {
      step(`Deleting an old screenshot [${w.locale}]…`);
      await asc(jwt, `/appScreenshots/${id}`, { method: "DELETE" });
    }
    for (const shot of w.shots) {
      step(`Uploading [${w.locale}] ${shot.fileName}…`);
      const bytes = await Deno.readFile(shot.path);
      const reservation = await asc(jwt, `/appScreenshots`, {
        method: "POST",
        body: JSON.stringify({ data: {
          type: "appScreenshots",
          attributes: { fileName: shot.fileName, fileSize: shot.size },
          relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: setId } } },
        } }),
      });
      for (const op of reservation.data.attributes.uploadOperations) {
        const response = await fetch(op.url, {
          method: op.method,
          headers: Object.fromEntries(op.requestHeaders.map((h: Json) => [h.name, h.value])),
          body: bytes.slice(op.offset, op.offset + op.length),
        });
        if (!response.ok) throw new Error(`upload part ${op.offset}+${op.length} → ${response.status}: ${await response.text()}`);
      }
      await asc(jwt, `/appScreenshots/${reservation.data.id}`, {
        method: "PATCH",
        body: JSON.stringify({ data: { type: "appScreenshots", id: reservation.data.id, attributes: { uploaded: true, sourceFileChecksum: shot.md5 } } }),
      });
    }
  }

  // Apple processes uploads asynchronously; COMPLETE is the only state that means the image will appear.
  step("Read-back verification: waiting for Apple to process the uploads…");
  for (let attempt = 0; attempt < 30; attempt++) {
    let mismatched = 0;
    for (const w of work) {
      const live = await readSet(locId[w.locale]);
      if (planScreenshotSet(w.shots, live?.shots ?? []).action !== "match") mismatched++;
    }
    if (mismatched === 0) { pass("Read-back verified: every locale's screenshots match and are COMPLETE."); Deno.exit(0); }
    await new Promise((resolve) => setTimeout(resolve, 10_000));
  }
  fail("Read-back mismatch after 5 minutes: some screenshots did not reach COMPLETE. Re-run `dump`, then `apply`.");
  Deno.exit(1);
}
