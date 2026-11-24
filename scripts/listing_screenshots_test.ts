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

import { assetUrl, carryLocale, carryLocales, type CarryApi, planCarry } from "./listing_screenshots.ts";

const shot = (n: string) => ({ attributes: { fileName: n, imageAsset: { templateUrl: `https://cdn/${n}/{w}x{h}.{f}`, width: 2880, height: 1800 } } });
function fakeApi(editableSets: { id: string; type: string; shots: string[] }[]) {
  const calls: { method: string; path: string; body?: Record<string, unknown> }[] = [];
  const uploads: string[] = [];
  const liveSets = [{ id: "L1", type: "APP_DESKTOP", shots: ["a.png", "b.png"] }];
  const api: CarryApi = {
    asc: (path, init) => {
      const method = init?.method ?? "GET";
      calls.push({ method, path, body: init?.body ? JSON.parse(init.body as string) : undefined });
      const sets = path.includes("live-loc") ? liveSets : editableSets;
      if (method === "GET" && path.endsWith("/appScreenshotSets?limit=50")) {
        return Promise.resolve({ data: sets.map((s) => ({ id: s.id, attributes: { screenshotDisplayType: s.type } })) });
      }
      const m = /appScreenshotSets\/(.+)\/appScreenshots/.exec(path);
      if (method === "GET" && m) {
        const all = [...liveSets, ...editableSets].find((s) => s.id === m[1])!;
        return Promise.resolve({ data: all.shots.map(shot) });
      }
      if (method === "POST" && path === "/appScreenshotSets") return Promise.resolve({ data: { id: "NEW" } });
      if (method === "POST" && path === "/appScreenshots") {
        return Promise.resolve({ data: { id: "R", attributes: { uploadOperations: [{ url: "https://up/1", method: "PUT", offset: 0, length: 3, requestHeaders: [{ name: "X", value: "y" }] }] } } });
      }
      return Promise.resolve(null);
    },
    fetch: (url) => {
      uploads.push(url);
      return Promise.resolve(new Response(new Uint8Array([1, 2, 3])));
    },
  };
  return { api, calls, uploads };
}
// the fake keys the live side off "live-loc" in the localization id
const LIVE = "live-loc";

Deno.test("carry: planCarry skips sets the editable version already has", () => {
  const live = [{ displayType: "APP_DESKTOP", shots: [{ fileName: "a", downloadUrl: "u" }] }];
  assertEquals(planCarry(live, []).length, 1);
  assertEquals(planCarry(live, [{ displayType: "APP_DESKTOP", count: 1 }]).length, 0);
  assertEquals(planCarry(live, [{ displayType: "APP_DESKTOP", count: 0 }]).length, 1);
});

Deno.test("carry: only locales the repo has no screenshots for", () => {
  assertEquals(carryLocales(["ms", "en-US", "de"], ["ms", "en-US"], ["de", "ms"]), ["en-US"]);
});

Deno.test("carry: assetUrl fills the template", () => {
  assertEquals(assetUrl({ templateUrl: "https://x/{w}x{h}.{f}", width: 2, height: 3 }), "https://x/2x3.png");
});

Deno.test("carry: live sets are copied into an empty editable version in order", async () => {
  const { api, calls, uploads } = fakeApi([]);
  const copied = await carryLocale(api, "ms", LIVE, "edit-loc", false);
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
  assertEquals(await carryLocale(api, "ms", LIVE, "edit-loc", false), []);
  assertEquals(calls.filter((c) => c.method !== "GET").length, 0);
  assertEquals(uploads.length, 0);
});

Deno.test("carry: dry run writes and downloads nothing", async () => {
  const { api, calls, uploads } = fakeApi([]);
  const lines: string[] = [];
  api.log = (m) => lines.push(m);
  assertEquals((await carryLocale(api, "ms", LIVE, "edit-loc", true)).length, 1);
  assertEquals(calls.filter((c) => c.method !== "GET").length, 0);
  assertEquals(uploads.length, 0);
  assertEquals(lines.length, 1);
});
