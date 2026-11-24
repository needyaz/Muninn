import type { Json } from "./lib/asc.ts";
import { assertEquals } from "./lib/assert.ts";
import { imageSize, isMacSize, type LiveShot, type LocalShot, planScreenshotSet, validateSet } from "./listing_screenshots.ts";

const local = (name: string, md5 = name): LocalShot => ({ fileName: name, md5, size: 1, path: `/x/${name}` });
const live = (name: string, md5 = name, state = "COMPLETE"): LiveShot => ({ id: `id-${name}`, fileName: name, md5, state });

Deno.test("MUN-BLD-003: an identical, fully processed set matches", () => {
  assertEquals(planScreenshotSet([local("01"), local("02")], [live("01"), live("02")]), { action: "match" });
});

Deno.test("MUN-BLD-003: any difference replaces the whole set, because order comes from upload order", () => {
  const plan = planScreenshotSet([local("01"), local("02", "new")], [live("01"), live("02")]);
  assertEquals(plan, { action: "replace", deleteIds: ["id-01", "id-02"], upload: ["01", "02"] });
});

Deno.test("MUN-BLD-003: a missing, extra, reordered or still-processing screenshot is a difference", () => {
  assertEquals(planScreenshotSet([local("01")], []).action, "replace");
  assertEquals(planScreenshotSet([local("01")], [live("01"), live("02")]).action, "replace");
  assertEquals(planScreenshotSet([local("01"), local("02")], [live("02"), live("01")]).action, "replace");
  assertEquals(planScreenshotSet([local("01")], [live("01", "01", "UPLOAD_COMPLETE")]).action, "replace");
});

Deno.test("MUN-BLD-003: Mac sizes are the four Apple lists", () => {
  for (const [w, h] of [[1280, 800], [1440, 900], [2560, 1600], [2880, 1800]]) assertEquals(isMacSize(w, h), true);
  assertEquals(isMacSize(1290, 2796), false, "an iPhone size");
  assertEquals(isMacSize(2880, 1801), false);
});

Deno.test("MUN-BLD-003: validateSet flags wrong sizes, mixed sizes and more than ten", () => {
  const ok = { fileName: "a.png", w: 2880, h: 1800 };
  assertEquals(validateSet("ms", [ok]), []);
  assertEquals(validateSet("ms", [{ ...ok, w: 1000, h: 700 }]).length, 1);
  assertEquals(validateSet("ms", [ok, { fileName: "b.png", w: 1440, h: 900 }]).length, 1);
  assertEquals(validateSet("ms", Array.from({ length: 11 }, (_, i) => ({ ...ok, fileName: `${i}.png` }))).length, 1);
});

Deno.test("MUN-BLD-003: an empty screenshot set has no problems (nothing is rendered yet)", () => {
  assertEquals(validateSet("ms", []), []);
});

Deno.test("MUN-BLD-003: imageSize reads a PNG header", () => {
  const png = new Uint8Array(32);
  png.set([0x89, 0x50, 0x4e, 0x47]);
  new DataView(png.buffer).setUint32(16, 2880);
  new DataView(png.buffer).setUint32(20, 1800);
  assertEquals(imageSize(png), { w: 2880, h: 1800 });
  assertEquals(imageSize(new Uint8Array([1, 2, 3])), null);
});

Deno.test("MUN-BLD-003: the committed screenshots, if any, are all one valid Mac size", async () => {
  const dir = new URL("../listing/screenshots/ms/", import.meta.url).pathname;
  const names = [...Deno.readDirSync(dir)].filter((e) => e.name.endsWith(".png")).map((e) => e.name).sort();
  const shots = [];
  for (const fileName of names) shots.push({ fileName, ...imageSize(await Deno.readFile(dir + fileName))! });
  assertEquals(validateSet("ms", shots), []);
});

// ---- carry: recorded responses, no network ----

import { assetUrl, carryLocale, carryLocales, type CarryApi, nothingComparedReason, planCarry, planStale } from "./listing_screenshots.ts";

type Spec = string | { n: string; state: string; error?: string };
const shot = (x: Spec) => {
  const { n, state, error } = typeof x === "string" ? { n: x, state: "COMPLETE", error: undefined } : x;
  return { id: `s-${n}`, attributes: { fileName: n, assetDeliveryState: { state, errors: error ? [{ description: error }] : [] }, imageAsset: { templateUrl: `https://cdn/${n}/{w}x{h}.{f}`, width: 2880, height: 1800 } } };
};
type FakeSet = { id: string; type: string; shots: Spec[] };
/** `afterCommit` is what the editable side reports once a screenshot has been committed (default: the sets as given). */
function fakeApi(editableSets: FakeSet[], afterCommit?: FakeSet[]) {
  let committed = false;
  const calls: { method: string; path: string; body?: Record<string, unknown> }[] = [];
  const uploads: string[] = [];
  const liveSets: FakeSet[] = [{ id: "L1", type: "APP_DESKTOP", shots: ["a.png", "b.png"] }];
  const api: CarryApi = {
    asc: (path, init) => {
      const method = init?.method ?? "GET";
      calls.push({ method, path, body: init?.body ? JSON.parse(init.body as string) : undefined });
      const sets = path.includes("live-loc") ? liveSets : committed && afterCommit ? afterCommit : editableSets;
      if (method === "GET" && path.endsWith("/appScreenshotSets?limit=50")) {
        return Promise.resolve({ data: sets.map((s) => ({ id: s.id, attributes: { screenshotDisplayType: s.type } })) });
      }
      const m = /appScreenshotSets\/(.+)\/appScreenshots/.exec(path);
      if (method === "GET" && m) {
        const all = [...liveSets, ...sets].find((s) => s.id === m[1])!;
        return Promise.resolve({ data: all.shots.map(shot) });
      }
      if (method === "POST" && path === "/appScreenshotSets") return Promise.resolve({ data: { id: "NEW" } });
      if (method === "POST" && path === "/appScreenshots") {
        return Promise.resolve({ data: { id: "R", attributes: { uploadOperations: [{ url: "https://up/1", method: "PUT", offset: 0, length: 3, requestHeaders: [{ name: "X", value: "y" }] }] } } });
      }
      if (method === "PATCH") committed = true;
      return Promise.resolve(null);
    },
    sleep: () => Promise.resolve(),
    pollIntervalMs: 1,
    pollTimeoutMs: 3,
    fetch: (url) => {
      uploads.push(url);
      return Promise.resolve(new Response(new Uint8Array([1, 2, 3])));
    },
  };
  return { api, calls, uploads };
}
// the fake keys the live side off "live-loc" in the localization id
const LIVE = "live-loc";

Deno.test("carry: planCarry compares whole sets", () => {
  const live = [{ displayType: "APP_DESKTOP", shots: [{ fileName: "a", downloadUrl: "u" }] }];
  const have = (...states: string[]) => [{ displayType: "APP_DESKTOP", shots: states.map((state) => ({ fileName: "a", downloadUrl: "u", state })) }];
  assertEquals(planCarry(live, []).length, 1);
  assertEquals(planCarry(live, have("COMPLETE")).length, 0);
  assertEquals(planCarry(live, have()).length, 1);
  assertEquals(planCarry(live, have("COMPLETE", "COMPLETE")).length, 1);
  assertEquals(planCarry(live, have("FAILED")).length, 1);
  assertEquals(planCarry(live, have("AWAITING_UPLOAD")).length, 1);
});

Deno.test("carry: only locales the repo has no screenshots for", () => {
  assertEquals(carryLocales(["ms", "en-US", "de"], ["ms", "en-US"], ["de", "ms"]), ["en-US"]);
});

Deno.test("carry: assetUrl fills the template", () => {
  assertEquals(assetUrl({ templateUrl: "https://x/{w}x{h}.{f}", width: 2, height: 3 }), "https://x/2x3.png");
});

Deno.test("carry: live sets are copied into an empty editable version in order", async () => {
  const { api, calls, uploads } = fakeApi([]);
  const { copied } = await carryLocale(api, "ms", LIVE, "edit-loc", false);
  assertEquals(copied, [{ displayType: "APP_DESKTOP", count: 2 }]);
  const posts = calls.filter((c) => c.method === "POST" && c.path === "/appScreenshots");
  assertEquals(posts.map((c) => (c.body as Json).data.attributes.fileName), ["a.png", "b.png"]);
  assertEquals(uploads, ["https://cdn/a.png/2880x1800.png", "https://up/1", "https://cdn/b.png/2880x1800.png", "https://up/1"]);
  const commits = calls.filter((c) => c.method === "PATCH");
  assertEquals(commits.length, 2);
  assertEquals((commits[0].body as Json).data.attributes.sourceFileChecksum.length, 32);
  assertEquals(calls.filter((c) => c.path === "/appScreenshotSets").length, 1);
});

Deno.test("carry: nothing is copied when the editable version already has the set", async () => {
  const { api, calls, uploads } = fakeApi([{ id: "E1", type: "APP_DESKTOP", shots: ["a.png", "b.png"] }]);
  assertEquals((await carryLocale(api, "ms", LIVE, "edit-loc", false)).copied, []);
  assertEquals(calls.filter((c) => c.method !== "GET").length, 0);
  assertEquals(uploads.length, 0);
});

Deno.test("carry: dry run writes and downloads nothing", async () => {
  const { api, calls, uploads } = fakeApi([]);
  const lines: string[] = [];
  api.log = (m) => lines.push(m);
  assertEquals((await carryLocale(api, "ms", LIVE, "edit-loc", true)).copied.length, 1);
  assertEquals(calls.filter((c) => c.method !== "GET").length, 0);
  assertEquals(uploads.length, 0);
  assertEquals(lines.length, 1);
});

Deno.test("carry: a partial editable set is deleted and replaced by the live set", async () => {
  const full = [{ id: "E1", type: "APP_DESKTOP", shots: ["a.png", "b.png"] }];
  const { api, calls } = fakeApi([{ id: "E1", type: "APP_DESKTOP", shots: ["a.png"] }], full);
  assertEquals((await carryLocale(api, "ms", LIVE, "edit-loc", false)).copied, [{ displayType: "APP_DESKTOP", count: 2 }]);
  assertEquals(calls.filter((c) => c.method === "DELETE").map((c) => c.path), ["/appScreenshots/s-a.png"]);
  assertEquals(calls.filter((c) => c.method === "POST" && c.path === "/appScreenshots").length, 2);
  assertEquals(calls.filter((c) => c.path === "/appScreenshotSets" && c.method === "POST").length, 0);
});

Deno.test("carry: a FAILED screenshot is replaced; a failure after commit is reported with Apple's error", async () => {
  const bad = [{ id: "E1", type: "APP_DESKTOP", shots: ["a.png", { n: "b.png", state: "FAILED" }] }];
  const { api, calls } = fakeApi(bad);
  let message = "";
  try {
    await carryLocale(api, "ms", LIVE, "edit-loc", false);
  } catch (e) {
    message = (e as Error).message;
  }
  assertEquals(calls.filter((c) => c.method === "DELETE").length, 2);
  assertEquals(message.includes("b.png failed"), true);
  const failedAfter = [{ id: "E1", type: "APP_DESKTOP", shots: ["a.png", { n: "b.png", state: "FAILED", error: "bad dimensions" }] }];
  const second = fakeApi([], failedAfter);
  let m2 = "";
  try {
    await carryLocale(second.api, "ms", LIVE, "edit-loc", false);
  } catch (e) {
    m2 = (e as Error).message;
  }
  assertEquals(m2.includes("bad dimensions"), true);
});

Deno.test("carry: a still-processing screenshot times out", async () => {
  const pending = [{ id: "E1", type: "APP_DESKTOP", shots: ["a.png", { n: "b.png", state: "UPLOAD_COMPLETE" }] }];
  const { api } = fakeApi([], pending);
  let message = "";
  try {
    await carryLocale(api, "ms", LIVE, "edit-loc", false);
  } catch (e) {
    message = (e as Error).message;
  }
  assertEquals(message.includes("timed out"), true);
});

Deno.test("carry: dry run reports live vs editable counts and states, and changes nothing", async () => {
  const { api, calls } = fakeApi([{ id: "E1", type: "APP_DESKTOP", shots: ["a.png", { n: "b.png", state: "FAILED" }] }]);
  const lines: string[] = [];
  api.log = (m) => lines.push(m);
  assertEquals((await carryLocale(api, "ms", LIVE, "edit-loc", true)).copied.length, 1);
  assertEquals(calls.filter((c) => c.method !== "GET").length, 0);
  assertEquals(lines, ["  [ms] APP_DESKTOP: live 2 (2 COMPLETE), editable 2 (1 COMPLETE, 1 FAILED) → would delete 2 and copy 2"]);
});

Deno.test("carry: dry run on a matching set says no change", async () => {
  const { api } = fakeApi([{ id: "E1", type: "APP_DESKTOP", shots: ["a.png", "b.png"] }]);
  const lines: string[] = [];
  api.log = (m) => lines.push(m);
  assertEquals((await carryLocale(api, "ms", LIVE, "edit-loc", true)).copied, []);
  assertEquals(lines[0].endsWith("→ no change"), true);
});

const STALE_FAILED = { id: "E2", type: "APP_DESKTOP_OLD", shots: [{ n: "x.png", state: "FAILED" }] as Spec[] };

Deno.test("carry: planStale picks editable sets the live version lacks that hold non-COMPLETE screenshots", () => {
  const sh = (state: string) => ({ fileName: "x", downloadUrl: "", state });
  const liveSets = [{ displayType: "APP_DESKTOP", shots: [sh("COMPLETE")] }];
  const stale = { displayType: "OTHER", shots: [sh("COMPLETE"), sh("FAILED")] };
  const clean = { displayType: "THIRD", shots: [sh("COMPLETE")] };
  const shared = { displayType: "APP_DESKTOP", shots: [sh("FAILED")] };
  assertEquals(planStale(liveSets, [stale, clean, shared]), [stale]);
});

Deno.test("carry: an editable set of a display type the live version lacks is deleted when it holds a non-COMPLETE screenshot", async () => {
  const { api, calls } = fakeApi([{ id: "E1", type: "APP_DESKTOP", shots: ["a.png", "b.png"] }, STALE_FAILED]);
  const r = await carryLocale(api, "ms", LIVE, "edit-loc", false);
  assertEquals(r.copied, []);
  assertEquals(r.removed, [{ displayType: "APP_DESKTOP_OLD", count: 1 }]);
  assertEquals(calls.filter((c) => c.method === "DELETE").map((c) => c.path), ["/appScreenshotSets/E2"]);
});

Deno.test("carry: dry run reports the stale set and deletes nothing", async () => {
  const { api, calls } = fakeApi([{ id: "E1", type: "APP_DESKTOP", shots: ["a.png", "b.png"] }, STALE_FAILED]);
  const lines: string[] = [];
  api.log = (m) => lines.push(m);
  const r = await carryLocale(api, "ms", LIVE, "edit-loc", true);
  assertEquals(r.removed.length, 1);
  assertEquals(calls.filter((c) => c.method !== "GET").length, 0);
  assertEquals(lines.some((l) => l.includes("APP_DESKTOP_OLD") && l.includes("would delete")), true);
});

Deno.test("carry: a COMPLETE set of another display type is left alone", async () => {
  const { api, calls } = fakeApi([{ id: "E1", type: "APP_DESKTOP", shots: ["a.png", "b.png"] }, { id: "E3", type: "APP_DESKTOP_OLD", shots: ["z.png"] }]);
  const r = await carryLocale(api, "ms", LIVE, "edit-loc", false);
  assertEquals(r.removed, []);
  assertEquals(calls.filter((c) => c.method !== "GET").length, 0);
});

Deno.test("carry: says why nothing was compared", () => {
  assertEquals(nothingComparedReason([], ["ms"], []), "the live version has no locales.");
  assertEquals(nothingComparedReason(["ms"], [], []), "the editable version has no locales.");
  assertEquals(nothingComparedReason(["de"], ["ms"], []), "the live and editable versions have no locale in common.");
  assertEquals(nothingComparedReason(["ms"], ["ms"], ["ms"]).startsWith("every shared locale (ms)"), true);
});
