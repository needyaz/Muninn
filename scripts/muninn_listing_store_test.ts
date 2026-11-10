// Checks for Muninn's App Store listing files and build-box release tooling (muninn-20261110-3).
// Run with: deno test --allow-read scripts/muninn_listing_store_test.ts
// The `make -n` and git checks also need --allow-run; without it they are reported as ignored.

const ROOT = new URL("../", import.meta.url);
const ROOT_PATH = ROOT.pathname;

function read(rel: string): string {
  return Deno.readTextFileSync(new URL(rel, ROOT));
}

function readJson(rel: string): Record<string, unknown> {
  return JSON.parse(read(rel));
}

function exists(rel: string): boolean {
  try {
    Deno.statSync(new URL(rel, ROOT));
    return true;
  } catch {
    return false;
  }
}

function fail(msg: string): never {
  throw new Error(msg);
}

function check(cond: boolean, msg: string): void {
  if (!cond) fail(msg);
}

function canRun(command: string): boolean {
  try {
    return Deno.permissions.querySync({ name: "run", command }).state === "granted";
  } catch {
    return false;
  }
}

function run(command: string, args: string[]): { code: number; out: string } {
  const result = new Deno.Command(command, { args, cwd: ROOT_PATH, stdout: "piped", stderr: "piped" }).outputSync();
  const dec = new TextDecoder();
  return { code: result.code, out: dec.decode(result.stdout) + dec.decode(result.stderr) };
}

function pngSize(bytes: Uint8Array): { w: number; h: number } | null {
  if (bytes.length < 24 || bytes[0] !== 0x89 || bytes[1] !== 0x50 || bytes[2] !== 0x4e || bytes[3] !== 0x47) return null;
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  return { w: view.getUint32(16), h: view.getUint32(20) };
}

const STORE_TARGETS = [
  "store-setup-diff",
  "store-setup-apply",
  "listing-dump",
  "listing-diff",
  "listing-apply",
  "screenshots-dump",
  "screenshots-diff",
  "screenshots-apply",
  "testflight",
  "beta",
  "release",
  "submit",
  "withdraw",
];

// Rule names from `make -p` output (the database of rules make actually loaded).
function loadedRules(boxName: string): Set<string> {
  const { out } = run("make", ["-pn", `BOX_NAME=${boxName}`, "help"]);
  const rules = new Set<string>();
  for (const line of out.split(/\r?\n/)) {
    const m = /^([A-Za-z0-9_.-]+):(?!=)/.exec(line);
    if (m) rules.add(m[1]);
  }
  return rules;
}

// MARK: - MUN-BLD-003

Deno.test("MUN-BLD-003: listing/app.json declares Productivity, no third-party content, free and age rating all NONE", () => {
  const app = readJson("listing/app.json");
  check(app.primaryCategory === "PRODUCTIVITY", `primaryCategory is ${app.primaryCategory}`);
  check(
    app.contentRightsDeclaration === "DOES_NOT_USE_THIRD_PARTY_CONTENT",
    `contentRightsDeclaration is ${app.contentRightsDeclaration}`,
  );
  check(app.free === true, "app.json does not say the app is free");
  const rating = app.ageRating as Record<string, unknown> | undefined;
  check(rating !== undefined && typeof rating === "object", "app.json has no ageRating");
  const entries = Object.entries(rating!);
  check(entries.some(([, v]) => typeof v === "string"), "ageRating has no rating levels");
  for (const [key, value] of entries) {
    if (typeof value === "string") check(value === "NONE", `ageRating.${key} is ${value}, not NONE`);
    else if (typeof value === "boolean") check(value === false, `ageRating.${key} is true`);
    else fail(`ageRating.${key} has an unexpected value ${JSON.stringify(value)}`);
  }
});

Deno.test("MUN-BLD-003: listing/app.json says nothing about availability or territories", () => {
  const app = readJson("listing/app.json");
  check(!("allTerritories" in app), "app.json still has allTerritories");
});

Deno.test("MUN-BLD-003: listing/README.md explains the files, screenshot regeneration and the build box fill-in", () => {
  const readme = read("listing/README.md");
  check(readme.includes("metadata.json"), "listing/README.md does not mention metadata.json");
  check(readme.includes("app.json"), "listing/README.md does not mention app.json");
  check(readme.includes("make screenshots"), "listing/README.md does not say how to regenerate screenshots");
  check(/App Store Connect/.test(readme), "listing/README.md does not mention App Store Connect");
  check(/build box/i.test(readme), "listing/README.md does not mention the build box");
});

Deno.test("MUN-BLD-003: listing/screenshots/en-US holds a .gitkeep or only 2880x1800 PNGs", () => {
  const dir = "listing/screenshots/en-US/";
  check(exists(dir), "listing/screenshots/en-US/ does not exist");
  const names = [...Deno.readDirSync(new URL(dir, ROOT))].map((e) => e.name);
  const pngs = names.filter((n) => n.toLowerCase().endsWith(".png"));
  if (pngs.length === 0) {
    check(names.includes(".gitkeep"), "no screenshots and no .gitkeep in listing/screenshots/en-US/");
    return;
  }
  check(pngs.length <= 10, `${pngs.length} screenshots; Apple allows at most 10`);
  for (const name of pngs) {
    const size = pngSize(Deno.readFileSync(new URL(dir + name, ROOT)));
    check(size !== null, `${name} is not a PNG`);
    check(size!.w === 2880 && size!.h === 1800, `${name} is ${size!.w}x${size!.h}`);
  }
});

Deno.test("MUN-BLD-003: the ported metadata validator accepts the committed listing and rejects a 31-character name", async () => {
  const mod = await import(new URL("./listing_metadata.ts", import.meta.url).href);
  const file = readJson("listing/metadata.json");
  const problems: string[] = mod.validate(file);
  check(problems.length === 0, `committed metadata.json is invalid: ${problems.join("; ")}`);
  const locs = file.localizations as Record<string, Record<string, string>>;
  const tooLong = { ...file, localizations: { "en-US": { ...locs["en-US"], name: "n".repeat(31) } } };
  check(mod.validate(tooLong).length > 0, "a 31-character name passes validation");
});

Deno.test("MUN-BLD-003: the ported screenshot check accepts the Mac 2880x1800 size and rejects an iPhone size", async () => {
  const mod = await import(new URL("./listing_screenshots.ts", import.meta.url).href);
  check(mod.isMacSize(2880, 1800) === true, "2880x1800 is not accepted as a Mac size");
  check(mod.isMacSize(1290, 2796) === false, "an iPhone size is accepted as a Mac size");
  const bad: string[] = mod.validateSet("en-US", [{ fileName: "01.png", w: 1000, h: 700 }]);
  check(bad.length > 0, "a wrong-size screenshot passes validateSet");
});

Deno.test("MUN-BLD-003: metadata.json keeps appStoreId and adds no subtitle, keywords, promotional text or URLs (keeps)", () => {
  const file = readJson("listing/metadata.json");
  check(file.appStoreId === "6759760573", `appStoreId is ${JSON.stringify(file.appStoreId)}`);
  const locs = file.localizations as Record<string, Record<string, string>>;
  for (const [locale, loc] of Object.entries(locs)) {
    for (const key of Object.keys(loc)) {
      check(!["subtitle", "keywords", "promotionalText"].includes(key), `[${locale}] has ${key}`);
      check(!/url$/i.test(key), `[${locale}] has ${key}`);
    }
  }
});

// MARK: - MUN-BLD-005

Deno.test("MUN-BLD-005: make/store.mk takes the App Store Connect key settings from the environment", () => {
  const mk = read("make/store.mk");
  for (const name of ["ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_FILEPATH"]) {
    check(mk.includes(`$(${name})`), `store.mk does not read ${name}`);
    const assigned = new RegExp(`^\\s*(export\\s+)?${name}\\s*(:|\\?|\\+)?=`, "m");
    check(!assigned.test(mk), `store.mk assigns ${name} instead of taking it from the environment`);
  }
});

Deno.test("MUN-BLD-005: DISTRIBUTION.md describes the App Store via the build box and GitHub Releases", () => {
  const doc = read("DISTRIBUTION.md");
  check(/App Store/.test(doc) && /build box/i.test(doc), "DISTRIBUTION.md does not describe the App Store via the build box");
  check(doc.includes("make github-release"), "DISTRIBUTION.md does not describe make github-release");
  check(/GitHub Release/.test(doc), "DISTRIBUTION.md does not mention GitHub Releases");
});

Deno.test("MUN-BLD-005: no file in the repository contains a private key (keeps)", () => {
  const marker = "BEGIN " + "PRIVATE KEY";
  const skip = new Set([".git", "build", "DerivedData", "node_modules", ".build"]);
  const hits: string[] = [];
  const walk = (url: URL, rel: string) => {
    for (const entry of Deno.readDirSync(url)) {
      if (skip.has(entry.name) || entry.name.endsWith(".xcodeproj")) continue;
      const childRel = rel + entry.name;
      if (entry.isDirectory) {
        walk(new URL(entry.name + "/", url), childRel + "/");
      } else if (entry.isFile) {
        if (entry.name.endsWith(".p8")) {
          hits.push(childRel);
          continue;
        }
        const bytes = Deno.readFileSync(new URL(entry.name, url));
        if (bytes.length > 5_000_000) continue;
        if (new TextDecoder().decode(bytes).includes(marker)) hits.push(childRel);
      }
    }
  };
  walk(ROOT, "");
  check(hits.length === 0, `key material found:\n${hits.join("\n")}`);
});

Deno.test({
  name: "MUN-BLD-005: the store targets exist only with the build-box declaration",
  fn: () => {
    if (!canRun("make")) {
      // Without permission to run make, check that the included file defines every store target.
      const mk = read("make/store.mk");
      for (const target of STORE_TARGETS) {
        check(new RegExp(`^${target}\\s*:(?!=)`, "m").test(mk), `store.mk does not define ${target}`);
      }
      return;
    }
    const box = loadedRules("prod-build");
    const dev = loadedRules("dev");
    for (const target of STORE_TARGETS) {
      check(box.has(target), `${target} is missing with BOX_NAME=prod-build`);
      check(!dev.has(target), `${target} exists without the build-box declaration`);
    }
  },
});

Deno.test("MUN-BLD-005: make/store.mk leaves github-release to the root Makefile", () => {
  const mk = read("make/store.mk");
  check(!/^github-release\s*:(?!=)/m.test(mk), "store.mk defines its own github-release target");
  check(/^[A-Za-z0-9_-]+\s*:(?!=)/m.test(mk), "store.mk defines no targets");
});
