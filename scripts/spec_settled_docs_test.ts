// Documentation checks for the spec conflicts settled in muninn-20261110-1.
// These read documents and UI string files, not product logic: the wording is the requirement.
// Run with: deno test --allow-read scripts/spec_settled_docs_test.ts

const ROOT = new URL("../", import.meta.url);

function read(rel: string): string {
  return Deno.readTextFileSync(new URL(rel, ROOT));
}

function lines(text: string): string[] {
  return text.split(/\r?\n/);
}

function fail(msg: string): never {
  throw new Error(msg);
}

function check(cond: boolean, msg: string): void {
  if (!cond) fail(msg);
}

function offending(text: string, patterns: RegExp[]): string[] {
  const hits: string[] = [];
  for (const line of lines(text)) {
    for (const p of patterns) {
      if (p.test(line)) {
        hits.push(line.trim());
        break;
      }
    }
  }
  return hits;
}

function swiftFiles(dirRel: string): string[] {
  const out: string[] = [];
  const walk = (url: URL, rel: string) => {
    for (const entry of Deno.readDirSync(url)) {
      const childRel = rel + entry.name;
      if (entry.isDirectory) {
        walk(new URL(entry.name + "/", url), childRel + "/");
      } else if (entry.isFile && entry.name.endsWith(".swift")) {
        out.push(childRel);
      }
    }
  };
  walk(new URL(dirRel, ROOT), dirRel);
  return out;
}

// Wordings that claim Muninn pastes into the other app itself.
const PASTES_FOR_YOU: RegExp[] = [
  /\bpastes? (it |them )?into (your|the) /i,
  /\band pastes? (it|them)\b/i,
  /\bpaste the selected (item|snippet)\b/i,
  /\b(navigate|return|enter) (and|to) paste\b/i,
  /\bquick-?paste\b/i,
  /\bquickly paste\b/i,
];

const POP_DOCS = [
  "SPEC.md",
  "README.md",
  "Muninn/HelpView.swift",
  "Muninn/OnboardingView.swift",
];

// MARK: - MUN-POP-001

for (const doc of POP_DOCS) {
  Deno.test(`MUN-POP-001: ${doc} does not say Muninn pastes into the previous app`, () => {
    const hits = offending(read(doc), PASTES_FOR_YOU);
    check(hits.length === 0, `${doc} still claims Muninn pastes for the user:\n${hits.join("\n")}`);
  });

}

const CMD_V = /(Cmd|Command|⌘)\s*\+?\s*V\b/;

// README.md already says this; it must keep saying it.
Deno.test("MUN-POP-001: README.md tells the user to press Cmd+V (keeps)", () => {
  check(CMD_V.test(read("README.md")), "README.md does not mention pressing Cmd+V");
});

for (const doc of ["SPEC.md", "Muninn/HelpView.swift", "Muninn/OnboardingView.swift"]) {
  Deno.test(`MUN-POP-001: ${doc} tells the user to press Cmd+V`, () => {
    check(CMD_V.test(read(doc)), `${doc} does not mention pressing Cmd+V`);
  });
}

Deno.test("MUN-POP-001: Help's click-an-item row says it copies, without pasting for the user", () => {
  const help = read("Muninn/HelpView.swift");
  const row = lines(help).find((l) => /Click an item/i.test(l)) ?? fail("no 'Click an item' help row");
  check(/cop(y|ies)/i.test(row), `Click-an-item help row does not say the item is copied: ${row.trim()}`);
  check(offending(row, PASTES_FOR_YOU).length === 0, `Click-an-item help row still says Muninn pastes: ${row.trim()}`);
});

Deno.test("MUN-POP-001: no Swift file posts key events or asks for Accessibility (keeps)", () => {
  const forbidden = [/CGEvent\s*\(/, /CGEventSource/, /CGEventPost/, /\.post\(\s*tap:/, /AXIsProcessTrusted/];
  const hits: string[] = [];
  for (const file of swiftFiles("Muninn/")) {
    for (const line of offending(read(file), forbidden)) hits.push(`${file}: ${line}`);
  }
  check(hits.length === 0, `key-event or Accessibility use found:\n${hits.join("\n")}`);
});

// MARK: - MUN-SENS-007

Deno.test("MUN-SENS-007: docs/ARCHITECTURE.md gives the sensitive preview as \"Sensitive content\"", () => {
  const arch = read("docs/ARCHITECTURE.md");
  check(!arch.includes("•"), "docs/ARCHITECTURE.md still describes the sensitive preview as bullets");
  check(
    lines(arch).some((l) => /preview/i.test(l) && l.includes("Sensitive content")),
    "docs/ARCHITECTURE.md does not say the sensitive preview reads \"Sensitive content\"",
  );
});

// MARK: - MUN-EXCL-005

Deno.test("MUN-EXCL-005: docs/ARCHITECTURE.md names excluded_apps.json and excluded_types.json", () => {
  const arch = read("docs/ARCHITECTURE.md");
  check(!arch.includes("excludedApps.json"), "docs/ARCHITECTURE.md still names excludedApps.json");
  check(!arch.includes("excludedTypes.json"), "docs/ARCHITECTURE.md still names excludedTypes.json");
  check(arch.includes("excluded_apps.json"), "docs/ARCHITECTURE.md does not name excluded_apps.json");
  check(arch.includes("excluded_types.json"), "docs/ARCHITECTURE.md does not name excluded_types.json");
});

// MARK: - MUN-SHOT-004

Deno.test("MUN-SHOT-004: docs/ARCHITECTURE.md describes the screenshot retry as linear", () => {
  const arch = read("docs/ARCHITECTURE.md");
  check(!/exponential/i.test(arch), "docs/ARCHITECTURE.md still calls the screenshot retry exponential");
  check(
    lines(arch).some((l) => /ScreenshotMonitor/.test(l) && /linear/i.test(l)),
    "docs/ARCHITECTURE.md does not describe the ScreenshotMonitor retry as a linear backoff",
  );
});

// MARK: - MUN-STOR-006

Deno.test("MUN-STOR-006: SPEC.md no longer lists a ~/.config/clipbar migration", () => {
  check(!read("SPEC.md").includes("~/.config/clipbar"), "SPEC.md still mentions ~/.config/clipbar");
});

// MARK: - MUN-PORT-018

Deno.test("MUN-PORT-018: docs/ARCHITECTURE.md describes Replace imports as staged, not a bare overwrite", () => {
  const arch = read("docs/ARCHITECTURE.md");
  const bare = lines(arch).filter((l) => /Replace\W*full overwrite/i.test(l) && !/stag/i.test(l));
  check(bare.length === 0, `docs/ARCHITECTURE.md still calls Replace a full overwrite:\n${bare.join("\n")}`);
  check(
    lines(arch).some((l) => /Replace/.test(l) && /stag/i.test(l) && /fail/i.test(l)),
    "docs/ARCHITECTURE.md does not say Replace imports are staged so a failure keeps existing data",
  );
});

// MARK: - MUN-INTN-006

Deno.test("MUN-INTN-006: README describes Get Latest Clipboard Item's non-text result as a preview", () => {
  const readme = read("README.md");
  const line = lines(readme).find((l) => /Get Latest Clipboard Item/.test(l)) ??
    fail("README.md does not describe Get Latest Clipboard Item");
  check(!/content description/i.test(line), `README still says a content description is returned: ${line.trim()}`);
  check(!/"Image"/.test(line), `README still gives "Image" as the result: ${line.trim()}`);
  check(/preview/i.test(line), `README does not say the newest item's preview is returned: ${line.trim()}`);
});

// MARK: - MUN-ONB-003

Deno.test("MUN-ONB-003: README says closing the onboarding window marks it as seen", () => {
  const readme = read("README.md");
  const onlyGetStarted = lines(readme).filter((l) =>
    /after you click\W+Get Started/i.test(l) && !/clos/i.test(l)
  );
  check(onlyGetStarted.length === 0, `README says onboarding stops only after Get Started:\n${onlyGetStarted.join("\n")}`);
  const start = readme.search(/^#+ Onboarding\s*$/m);
  check(start >= 0, "README.md has no Onboarding section");
  const rest = readme.slice(start).split(/\r?\n/).slice(1);
  const end = rest.findIndex((l) => /^#+ /.test(l));
  const section = (end >= 0 ? rest.slice(0, end) : rest).join("\n");
  check(/clos/i.test(section), "README's Onboarding section does not say closing the window counts as seen");
});

Deno.test("MUN-ONB-003: docs/ARCHITECTURE.md says closing the onboarding window marks it as seen", () => {
  const arch = read("docs/ARCHITECTURE.md");
  check(
    lines(arch).some((l) => /onboarding/i.test(l) && /clos/i.test(l) && /seen|hasSeenOnboarding/i.test(l)),
    "docs/ARCHITECTURE.md does not say closing the onboarding window sets hasSeenOnboarding",
  );
});

// MARK: - MUN-PRIV-004

Deno.test("MUN-PRIV-004: docs/ARCHITECTURE.md gives KeyboardShortcuts as pinned to 2.4.0", () => {
  const arch = read("docs/ARCHITECTURE.md");
  const ks = lines(arch).filter((l) => /KeyboardShortcuts/.test(l));
  check(!ks.some((l) => l.includes(">=")), "docs/ARCHITECTURE.md still gives KeyboardShortcuts a minimum version");
  check(
    ks.some((l) => l.includes("2.4.0") && /pinned/i.test(l)),
    "docs/ARCHITECTURE.md does not say KeyboardShortcuts is pinned to 2.4.0",
  );
});
