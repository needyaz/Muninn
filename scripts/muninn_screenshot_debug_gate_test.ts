// MUN-BLD-004: the screenshot mode must not be reachable in a Release build.
// Run with: deno test --allow-read scripts/muninn_screenshot_debug_gate_test.ts

const ROOT = new URL("../Muninn/", import.meta.url);

function lines(name: string): string[] {
  return Deno.readTextFileSync(new URL(name, ROOT)).split("\n");
}

/** Lines of `name` that are outside every `#if DEBUG` ... `#endif` region. */
function outsideDebug(name: string): string[] {
  const out: string[] = [];
  let depth = 0;
  let debugAt = -1;
  for (const raw of lines(name)) {
    const l = raw.trim();
    if (/^#if\b/.test(l)) {
      depth++;
      if (l === "#if DEBUG" && debugAt < 0) debugAt = depth;
      continue;
    }
    if (/^#(else|elseif)\b/.test(l) && debugAt === depth) {
      throw new Error(`${name}: #else inside the DEBUG guard`);
    }
    if (/^#endif\b/.test(l)) {
      if (debugAt === depth) debugAt = -1;
      depth--;
      continue;
    }
    if (debugAt < 0) out.push(raw);
  }
  return out;
}

for (const f of ["ScreenshotMode.swift", "ScreenshotFixtures.swift", "ScreenshotScenes.swift"]) {
  Deno.test(`MUN-BLD-004: ${f} is entirely inside #if DEBUG`, () => {
    const code = outsideDebug(f).filter((l) => l.trim() !== "" && !l.trim().startsWith("//"));
    if (code.length) throw new Error(`${f} has code outside #if DEBUG: ${code[0]}`);
  });
}

Deno.test("MUN-BLD-004: every other use of the screenshot mode is inside #if DEBUG", () => {
  const names = [...Deno.readDirSync(ROOT)]
    .map((e) => e.name)
    .filter((n) => n.endsWith(".swift") && !/^Screenshot(Mode|Fixtures|Scenes)\.swift$/.test(n));
  for (const n of names) {
    const hit = outsideDebug(n).find((l) =>
      !l.trim().startsWith("//") && /\b(ScreenshotMode|ScreenshotFixtures|ScreenshotScenes?)\b/.test(l)
    );
    if (hit) throw new Error(`${n} reaches the screenshot mode outside #if DEBUG: ${hit.trim()}`);
  }
});
