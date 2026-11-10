import { assertEquals } from "./lib/assert.ts";
import { actionFor, buildNumberFromVersion, explainRefusal, readiness } from "./submit.ts";

Deno.test("MUN-BLD-005: the build number is the last part of 1.0.<n>", () => {
  assertEquals(buildNumberFromVersion("1.0.77"), "77");
  assertEquals(buildNumberFromVersion("1.0"), null);
  assertEquals(buildNumberFromVersion("1.0.x"), null);
});

Deno.test("MUN-BLD-005: only an editable version is submitted; a waiting one is left alone", () => {
  assertEquals(actionFor("PREPARE_FOR_SUBMISSION"), "submit");
  assertEquals(actionFor("REJECTED"), "submit");
  assertEquals(actionFor("WAITING_FOR_REVIEW"), "already-submitted");
  assertEquals(actionFor("IN_REVIEW"), "already-submitted");
  assertEquals(actionFor("READY_FOR_SALE"), "approved-or-live");
});

Deno.test("MUN-BLD-005: a just-uploaded build is missing, then processing, then ready", () => {
  assertEquals(readiness(undefined), "missing");
  assertEquals(readiness({ processingState: "PROCESSING", expired: false }), "processing");
  assertEquals(readiness({ processingState: "VALID", expired: false }), "ready");
  assertEquals(readiness({ processingState: "FAILED", expired: false }), "unusable");
  assertEquals(readiness({ processingState: "VALID", expired: true }), "unusable");
});

Deno.test("MUN-BLD-005: a missing privacy answer is explained, other errors are left alone", () => {
  const apple = `ASC POST /reviewSubmissionItems → 409: {"code":"STATE_ERROR.APP_DATA_USAGES_REQUIRED"}`;
  assertEquals(explainRefusal(apple)?.includes("App Privacy"), true);
  assertEquals(explainRefusal("ASC POST /x → 500: boom"), null);
});
