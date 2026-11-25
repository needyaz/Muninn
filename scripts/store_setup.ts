/**
 * The App Store Connect settings that belong to the app, not to a version: content rights, category, age rating
 * and price. Desired state is listing/app.json. Idempotent: `diff` reads, `apply` writes only what
 * differs and then reads back. A setting the file does not mention is never touched (it says nothing about
 * availability, so where the live app is sold never changes). (Copyright, release type and the review contact live
 * with the version, in listing_metadata.ts. The privacy "nutrition label" has no API and is answered once in the web UI.)
 *
 *   deno run --allow-read scripts/store_setup.ts check
 *   deno run --allow-net --allow-env --allow-read scripts/store_setup.ts diff
 *   deno run --allow-net --allow-env --allow-read scripts/store_setup.ts apply
 */

import { asc, ascJwt, fail, findApp, type Json, pass, pickEditableInfo, step } from "./lib/asc.ts";

const DESIRED_PATH = new URL("../listing/app.json", import.meta.url).pathname;
const ROOT = "https://api.appstoreconnect.apple.com";

export interface AppDesired {
  contentRightsDeclaration: string;
  primaryCategory: string;
  /** Every age rating question: "NONE" / true / false. */
  ageRating: Record<string, string | boolean>;
  free: boolean;
  /** Optional: only when present does the tool touch availability. Muninn's app.json leaves it out. */
  allTerritories?: boolean;
}

export const CONTENT_RIGHTS = ["DOES_NOT_USE_THIRD_PARTY_CONTENT", "USES_THIRD_PARTY_CONTENT"];

export function validate(desired: AppDesired): string[] {
  const problems: string[] = [];
  if (!CONTENT_RIGHTS.includes(desired.contentRightsDeclaration)) problems.push(`contentRightsDeclaration must be one of ${CONTENT_RIGHTS.join(", ")}`);
  if (!/^[A-Z_]+$/.test(desired.primaryCategory ?? "")) problems.push("primaryCategory must be an App Store category id such as PRODUCTIVITY");
  if (Object.keys(desired.ageRating ?? {}).length === 0) problems.push("ageRating is empty");
  for (const [key, value] of Object.entries(desired.ageRating ?? {})) {
    if (typeof value === "string" && !["NONE", "INFREQUENT_OR_MILD", "FREQUENT_OR_INTENSE"].includes(value)) problems.push(`ageRating.${key}: "${value}" is not a rating level`);
  }
  return problems;
}

/** The settings whose live value differs from the desired one, as `name: have → want`. */
export function differences(live: Partial<AppDesired>, want: AppDesired, hasInfo = true): string[] {
  const out: string[] = [];
  if (live.contentRightsDeclaration !== want.contentRightsDeclaration) out.push(`contentRightsDeclaration: ${live.contentRightsDeclaration ?? "unset"} → ${want.contentRightsDeclaration}`);
  // Category and age rating live on the editable AppInfo; without one they cannot be read or written.
  if (hasInfo && live.primaryCategory !== want.primaryCategory) out.push(`primaryCategory: ${live.primaryCategory ?? "unset"} → ${want.primaryCategory}`);
  for (const [key, value] of hasInfo ? Object.entries(want.ageRating) : []) {
    if (live.ageRating?.[key] !== value) out.push(`ageRating.${key}: ${live.ageRating?.[key] ?? "unset"} → ${value}`);
  }
  if (want.free && live.free !== true) out.push(`price: ${live.free === undefined ? "unset" : "not free"} → free`);
  if (want.allTerritories && live.allTerritories !== true) out.push("availability: not set → all territories");
  return out;
}

type Ask = (jwt: string, path: string, init?: RequestInit) => Promise<Json>;
export interface StoreState { live: Partial<AppDesired>; infoId?: string; ageId?: string }

export async function read(jwt: string, appId: string, want: AppDesired, ask: Ask = asc): Promise<StoreState> {
  const app = (await ask(jwt, `/apps/${appId}`)).data;
  const info = pickEditableInfo<Json>((await ask(jwt, `/apps/${appId}/appInfos`)).data);
  // Between releases there is no editable AppInfo; content rights and price are app-level and still readable.
  const category = info ? await ask(jwt, `/appInfos/${info.id}/primaryCategory`).catch(() => null) : null;
  const age = info ? (await ask(jwt, `/appInfos/${info.id}/ageRatingDeclaration`)).data : undefined;

  let free: boolean | undefined;
  try {
    const manual = await ask(jwt, `/appPriceSchedules/${appId}/manualPrices?include=appPricePoint&limit=50`);
    const points: Json[] = manual.included ?? [];
    free = (manual.data ?? []).length > 0 && points.length > 0 && points.every((p) => p.attributes?.customerPrice === "0.0");
  } catch { /* no schedule yet */ }

  let allTerritories: boolean | undefined;
  if (want.allTerritories) {
    try {
      await ask(jwt, `/apps/${appId}/appAvailabilityV2`);
      allTerritories = true;
    } catch { /* not set yet */ }
  }

  return {
    infoId: info?.id,
    ageId: age?.id,
    live: {
      contentRightsDeclaration: app.attributes.contentRightsDeclaration ?? undefined,
      primaryCategory: category?.data?.id,
      ageRating: age ? Object.fromEntries(Object.keys(want.ageRating).map((k) => [k, age.attributes[k]])) : undefined,
      free,
      allTerritories,
    },
  };
}

async function apply(jwt: string, appId: string, want: AppDesired, state: StoreState) {
  const { live, infoId, ageId } = state;
  const hasInfo = infoId !== undefined && ageId !== undefined;
  if (live.contentRightsDeclaration !== want.contentRightsDeclaration) {
    step("Content rights…");
    await asc(jwt, `/apps/${appId}`, { method: "PATCH", body: JSON.stringify({ data: { type: "apps", id: appId, attributes: { contentRightsDeclaration: want.contentRightsDeclaration } } }) });
  }
  if (hasInfo && live.primaryCategory !== want.primaryCategory) {
    step("Primary category…");
    await asc(jwt, `/appInfos/${infoId}`, {
      method: "PATCH",
      body: JSON.stringify({ data: { type: "appInfos", id: infoId, relationships: { primaryCategory: { data: { type: "appCategories", id: want.primaryCategory } } } } }),
    });
  }
  if (hasInfo && Object.entries(want.ageRating).some(([k, v]) => live.ageRating?.[k] !== v)) {
    step("Age rating…");
    await asc(jwt, `/ageRatingDeclarations/${ageId}`, { method: "PATCH", body: JSON.stringify({ data: { type: "ageRatingDeclarations", id: ageId, attributes: want.ageRating } }) });
  }
  if (want.free && live.free !== true) {
    step("Price: free…");
    const points = (await asc(jwt, `/apps/${appId}/appPricePoints?filter[territory]=USA&limit=200`)).data;
    const free = points.find((p: Json) => p.attributes.customerPrice === "0.0");
    if (!free) throw new Error("no free price point found for USA");
    await asc(jwt, `/appPriceSchedules`, {
      method: "POST",
      body: JSON.stringify({
        data: { type: "appPriceSchedules", relationships: {
          app: { data: { type: "apps", id: appId } },
          baseTerritory: { data: { type: "territories", id: "USA" } },
          manualPrices: { data: [{ type: "appPrices", id: "${p1}" }] },
        } },
        included: [{ type: "appPrices", id: "${p1}", attributes: { startDate: null }, relationships: { appPricePoint: { data: { type: "appPricePoints", id: free.id } } } }],
      }),
    });
  }
  if (want.allTerritories && live.allTerritories !== true) {
    step("Availability: all territories…");
    const territories: string[] = [];
    let next = "/territories?limit=200";
    while (next) {
      const page = await asc(jwt, next);
      territories.push(...page.data.map((t: Json) => t.id));
      next = page.links?.next?.replace(`${ROOT}/v1`, "") ?? "";
    }
    await asc(jwt, `${ROOT}/v2/appAvailabilities`, {
      method: "POST",
      body: JSON.stringify({
        data: { type: "appAvailabilities", attributes: { availableInNewTerritories: true }, relationships: {
          app: { data: { type: "apps", id: appId } },
          territoryAvailabilities: { data: territories.map((t) => ({ type: "territoryAvailabilities", id: `\${${t}}` })) },
        } },
        included: territories.map((t) => ({ type: "territoryAvailabilities", id: `\${${t}}`, attributes: { available: true }, relationships: { territory: { data: { type: "territories", id: t } } } })),
      }),
    });
  }
}

if (import.meta.main) {
  const command = Deno.args[0];
  if (!["check", "diff", "apply"].includes(command ?? "")) {
    console.error("usage: store_setup.ts <check|diff|apply>");
    Deno.exit(1);
  }
  const want = JSON.parse(await Deno.readTextFile(DESIRED_PATH)) as AppDesired;
  const problems = validate(want);
  if (problems.length > 0) { problems.forEach(fail); Deno.exit(1); }
  if (command === "check") { pass("listing/app.json is valid"); Deno.exit(0); }

  const jwt = await ascJwt();
  const appId = await findApp(jwt);
  step("Reading the app's store settings…");
  const state = await read(jwt, appId, want);
  const hasInfo = state.infoId !== undefined;
  if (!hasInfo) console.log("  (no editable AppInfo: category and age rating are skipped; run `make listing-apply` to create the editable version)");
  const diff = differences(state.live, want, hasInfo);
  if (diff.length === 0) { pass("The app's store settings already match listing/app.json."); Deno.exit(0); }
  diff.forEach((d) => console.log(`  ${d}`));
  if (command === "diff") Deno.exit(1);

  await apply(jwt, appId, want, state);
  step("Read-back verification…");
  const after = differences((await read(jwt, appId, want)).live, want, hasInfo);
  if (after.length === 0) { pass("Read-back verified: the store matches listing/app.json."); Deno.exit(0); }
  fail("did not stick:");
  after.forEach((d) => console.log(`  ${d}`));
  Deno.exit(1);
}
