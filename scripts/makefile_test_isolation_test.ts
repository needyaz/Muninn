// The checks run on the owner's Mac: no target reachable from `make test` may quit, reset or delete the real
// Muninn (bundle id blue.luci.Muninn, process "Muninn"). Only the dev app ("Muninn Dev") is fair game.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

async function dryRun(...args: string[]): Promise<string> {
  const out = await new Deno.Command("make", {
    args: ["-n", "-C", new URL("..", import.meta.url).pathname, ...args],
    stdout: "piped",
    stderr: "piped",
  }).output();
  assertEquals(out.code, 0, new TextDecoder().decode(out.stderr));
  return new TextDecoder().decode(out.stdout);
}

Deno.test("make test does not quit or reset the real Muninn", async () => {
  const lines = (await dryRun("test")).split("\n");
  const destructive = lines.filter((l) => /\b(pkill|killall|tccutil|rm)\b/.test(l));
  for (const l of destructive) {
    const rest = l.replace(/blue\.luci\.Muninn\.dev(\.tests)?/g, "").replace(/Muninn Dev/g, "");
    assert(!/Muninn/.test(rest), `touches the real app: ${l}`);
  }
  assert(lines.some((l) => /pkill/.test(l)), "expected test to stop the dev app");
});

Deno.test("make test builds the dev app", async () => {
  const out = await dryRun("test");
  assertStringIncludes(out, "MUNINN_BUNDLE_ID=blue.luci.Muninn.dev");
  assertStringIncludes(out, 'MUNINN_PRODUCT_NAME="Muninn Dev"');
});

Deno.test("release targets keep the real bundle id", async () => {
  assertStringIncludes(await dryRun("build"), "MUNINN_BUNDLE_ID=blue.luci.Muninn ");
  assertStringIncludes(await dryRun("install"), "MUNINN_BUNDLE_ID=blue.luci.Muninn ");
});
