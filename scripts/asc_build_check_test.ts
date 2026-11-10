import { assertEquals } from "./lib/assert.ts";
import { classifyBuild } from "./asc_build_check.ts";
import "./asc_promote_beta.ts"; // type-checks the beta promotion script; it does nothing unless run directly

const b = (version: string, processingState: string, expired = false) => ({ version, processingState, expired });

Deno.test("MUN-BLD-005: no build with that number is ABSENT: build and upload as usual", () => {
  assertEquals(classifyBuild([b("120", "VALID")], "121"), "ABSENT");
  assertEquals(classifyBuild([], "121"), "ABSENT");
});

Deno.test("MUN-BLD-005: a VALID or still-PROCESSING build with that number is REUSE: skip build and upload", () => {
  assertEquals(classifyBuild([b("121", "VALID"), b("120", "VALID")], "121"), "REUSE");
  assertEquals(classifyBuild([b("121", "PROCESSING")], "121"), "REUSE");
});

Deno.test("MUN-BLD-005: a FAILED, INVALID or expired build with that number is BURNED: needs a new commit", () => {
  assertEquals(classifyBuild([b("121", "FAILED")], "121"), "BURNED");
  assertEquals(classifyBuild([b("121", "INVALID")], "121"), "BURNED");
  assertEquals(classifyBuild([b("121", "VALID", true)], "121"), "BURNED");
});

Deno.test("MUN-BLD-005: build numbers compare as exact strings: 12 is not 121", () => {
  assertEquals(classifyBuild([b("12", "VALID"), b("1210", "VALID")], "121"), "ABSENT");
});
