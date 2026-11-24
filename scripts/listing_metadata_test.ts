import { assertEquals } from "./lib/assert.ts";
import { attributesFor, computeDiff, type Desired, findInfoLocalization, needsEditableVersion, reviewContactFromEnv, validate, validateAppStoreId, versionPlan } from "./listing_metadata.ts";

const desired = (loc: Record<string, string>, review?: Record<string, string>): Desired => ({ localizations: { "en-US": loc }, review });

Deno.test("MUN-BLD-003: the committed listing is valid, names Muninn's app id and keeps the seeded name", async () => {
  const file = JSON.parse(await Deno.readTextFile(new URL("../listing/metadata.json", import.meta.url).pathname));
  assertEquals(validate(file), []);
  assertEquals(validateAppStoreId(file), []);
  assertEquals(file.localizations["en-US"].name, "Muninn");
});

Deno.test("MUN-BLD-003: the listing file must carry appStoreId 6759760573 as a string", () => {
  assertEquals(validateAppStoreId({ appStoreId: "6759760573", localizations: {} }), []);
  assertEquals(validateAppStoreId({ localizations: {} }).length, 1);
  assertEquals(validateAppStoreId({ appStoreId: "1234", localizations: {} }).length, 1);
  assertEquals(validateAppStoreId({ appStoreId: 6759760573 as never, localizations: {} }).length, 1);
});

Deno.test("MUN-BLD-003: validate enforces Apple's character limits", () => {
  assertEquals(validate(desired({ name: "x".repeat(30) })), []);
  assertEquals(validate(desired({ name: "x".repeat(31) })).length, 1);
  assertEquals(validate(desired({ subtitle: "y".repeat(31) })).length, 1);
  assertEquals(validate(desired({ keywords: "k".repeat(101) })).length, 1);
  assertEquals(validate(desired({ promotionalText: "p".repeat(171) })).length, 1);
  assertEquals(validate(desired({ description: "d".repeat(4001) })).length, 1);
});

Deno.test("MUN-BLD-003: validate counts characters, not UTF-16 units", () => {
  assertEquals(validate(desired({ name: "🔔".repeat(30) })), []);
});

Deno.test("MUN-BLD-003: validate rejects unknown or empty fields, bad URLs and padded keywords", () => {
  assertEquals(validate(desired({ title: "x" } as never)).length, 1);
  assertEquals(validate(desired({ name: "" })).length, 1);
  assertEquals(validate(desired({ supportUrl: "http://luci.blue/muninn" })).length, 1);
  assertEquals(validate(desired({ keywords: "a, b" })).length, 1);
  assertEquals(validate({ localizations: {} }).length, 1);
  assertEquals(validate(desired({ name: "x" }, { notes: "n".repeat(4001) })).length, 1);
  assertEquals(validate(desired({ name: "x" }, { password: "no" })).length, 1);
});

Deno.test("MUN-BLD-003: computeDiff looks only at the fields the file mentions", () => {
  const live: Desired = { localizations: { "en-US": { name: "Muninn", description: "old", keywords: "k" } }, review: { notes: "same" } };
  const want = desired({ description: "new", keywords: "k" }, { notes: "same" });
  assertEquals(computeDiff(live, want), [{ section: "version", locale: "en-US", field: "description", from: "old", to: "new" }]);
});

Deno.test("MUN-BLD-003: computeDiff reports a locale the store lacks as differences from empty", () => {
  const changes = computeDiff({ localizations: {} }, desired({ name: "Muninn", description: "d" }));
  assertEquals(changes.map((c) => [c.section, c.field]), [["info", "name"], ["version", "description"]]);
  assertEquals(changes.every((c) => c.from === ""), true);
});

Deno.test("MUN-BLD-003: computeDiff covers review notes and finds nothing when everything matches", () => {
  const live: Desired = { localizations: { "en-US": { name: "Muninn" } }, review: { notes: "old" } };
  assertEquals(computeDiff(live, desired({ name: "Muninn" }, { notes: "new" })).map((c) => c.section), ["review"]);
  assertEquals(computeDiff(live, desired({ name: "Muninn" }, { notes: "old" })), []);
});

Deno.test("MUN-BLD-003: only promotional text on an existing locale can change without an editable version", () => {
  const change = (section: "version" | "info" | "review", field: string) => ({ section, locale: "en-US", field, from: "", to: "x" });
  assertEquals(needsEditableVersion(change("version", "promotionalText"), true), false);
  assertEquals(needsEditableVersion(change("version", "promotionalText"), false), true);
  assertEquals(needsEditableVersion(change("version", "description"), true), true);
  assertEquals(needsEditableVersion(change("info", "name"), true), true);
  assertEquals(needsEditableVersion(change("review", "notes"), true), true);
});

Deno.test("MUN-BLD-003: version attributes are validated and diffed like the rest", () => {
  const withVersion = (version: Record<string, string>): Desired => ({ localizations: { "en-US": { name: "x" } }, version });
  assertEquals(validate(withVersion({ copyright: "© 2026 Blue Luci", releaseType: "MANUAL" })), []);
  assertEquals(validate(withVersion({ releaseType: "WHENEVER" })).length, 1);
  assertEquals(validate(withVersion({ price: "0" })).length, 1);
  const live: Desired = { localizations: { "en-US": { name: "x" } }, version: { copyright: "old", releaseType: "MANUAL" } };
  assertEquals(computeDiff(live, withVersion({ copyright: "new", releaseType: "MANUAL" })), [{ section: "release", field: "copyright", from: "old", to: "new" }]);
});

Deno.test("MUN-BLD-005: the review contact comes from the environment and only when set", () => {
  assertEquals(reviewContactFromEnv({}), {});
  assertEquals(reviewContactFromEnv({ REVIEW_CONTACT_FIRST_NAME: "A", REVIEW_CONTACT_EMAIL: "a@example.com", PATH: "/bin" }), { contactFirstName: "A", contactEmail: "a@example.com" });
});

Deno.test("MUN-BLD-005: the editable version is made to carry exactly the stamped version", () => {
  assertEquals(versionPlan({ versionString: "1.0.10", editable: true }, "1.0.10"), "none");
  assertEquals(versionPlan({ versionString: "1.0", editable: true }, "1.0.10"), "rename");
  assertEquals(versionPlan({ versionString: "1.0.9", editable: false }, "1.0.10"), "create");
  assertEquals(versionPlan({ versionString: "1.0.10", editable: false }, "1.0.10"), "none");
  assertEquals(versionPlan({ versionString: "1.0", editable: true }, undefined), "none");
});

Deno.test("MUN-BLD-005: a new version is blocked while one is with App Review", () => {
  assertEquals(versionPlan({ versionString: "1.0.13", editable: false, state: "WAITING_FOR_REVIEW" }, "1.0.17"), "blocked");
  assertEquals(versionPlan({ versionString: "1.0.13", editable: false, state: "IN_REVIEW" }, "1.0.17"), "blocked");
  assertEquals(versionPlan({ versionString: "1.0.13", editable: false, state: "WAITING_FOR_REVIEW" }, "1.0.13"), "none", "re-running the same release is fine");
  assertEquals(versionPlan({ versionString: "1.0.13", editable: false, state: "READY_FOR_SALE" }, "1.0.17"), "create");
  assertEquals(versionPlan({ versionString: "1.0", editable: true, state: "PREPARE_FOR_SUBMISSION" }, "1.0.17"), "rename");
});

Deno.test("release: an existing localization is updated, and an unchanged name is left out of the PATCH", () => {
  const live: Desired = { localizations: { "en-US": { name: "Muninn", subtitle: "old" } } };
  const want: Desired = { localizations: { "en-US": { name: "Muninn", subtitle: "new" } } };
  const changes = computeDiff(live, want);
  assertEquals(attributesFor("info", want.localizations["en-US"], changes, "en-US"), { subtitle: "new" });
  assertEquals(attributesFor("info", want.localizations["en-US"], computeDiff(want, want), "en-US"), {});
});

Deno.test("release: an existing en-US app info localization is found (after a lag) instead of being created", async () => {
  let calls = 0;
  const list = () => Promise.resolve(++calls < 3 ? [] : [{ id: "loc1", attributes: { locale: "en-US", name: "Muninn" } }]);
  assertEquals((await findInfoLocalization(list, "en-US", 4, () => Promise.resolve()))?.id, "loc1");
  assertEquals(calls, 3);
  assertEquals(await findInfoLocalization(() => Promise.resolve([]), "en-US", 2, () => Promise.resolve()), undefined);
});
