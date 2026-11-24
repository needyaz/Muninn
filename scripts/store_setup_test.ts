import { assertEquals } from "./lib/assert.ts";
import { assertAppId, pickEditableInfo } from "./lib/asc.ts";
import { type AppDesired, differences, validate } from "./store_setup.ts";

const want: AppDesired = {
  contentRightsDeclaration: "DOES_NOT_USE_THIRD_PARTY_CONTENT",
  primaryCategory: "PRODUCTIVITY",
  ageRating: { gambling: false, violenceRealistic: "NONE" },
  free: true,
};

Deno.test("MUN-BLD-003: the committed app settings are valid and say nothing about availability", async () => {
  const file = JSON.parse(await Deno.readTextFile(new URL("../listing/app.json", import.meta.url).pathname));
  assertEquals(validate(file), []);
  assertEquals("allTerritories" in file, false);
});

Deno.test("MUN-BLD-003: validate rejects unknown rights, categories and rating levels", () => {
  assertEquals(validate({ ...want, contentRightsDeclaration: "MAYBE" }).length, 1);
  assertEquals(validate({ ...want, primaryCategory: "productivity" }).length, 1);
  assertEquals(validate({ ...want, ageRating: { violenceRealistic: "SOME" } }).length, 1);
  assertEquals(validate({ ...want, ageRating: {} }).length, 1);
});

Deno.test("MUN-BLD-003: nothing differs when the store already matches", () => {
  assertEquals(differences({ ...want }, want), []);
});

Deno.test("MUN-BLD-003: an empty store differs in every setting the file mentions, and not in availability", () => {
  const out = differences({}, want);
  assertEquals(out.length, 5);
  assertEquals(out.some((line) => line.startsWith("price")), true);
  assertEquals(out.some((line) => line.startsWith("availability")), false);
});

Deno.test("MUN-BLD-003: only the settings that differ are reported", () => {
  const live = { ...want, primaryCategory: "UTILITIES", ageRating: { gambling: false, violenceRealistic: "NONE" } };
  assertEquals(differences(live, want), ["primaryCategory: UTILITIES → PRODUCTIVITY"]);
});

Deno.test("MUN-BLD-005: the tools refuse an app whose id is not Muninn's", () => {
  assertAppId("6759760573");
  let message = "";
  try {
    assertAppId("42");
  } catch (e) {
    message = String(e);
  }
  assertEquals(message.includes("6759760573"), true);
});

Deno.test("release: the age rating goes to the editable AppInfo, not the live one", () => {
  const infos = [
    { id: "live", attributes: { state: "READY_FOR_SALE" } },
    { id: "next", attributes: { state: "PREPARE_FOR_SUBMISSION" } },
  ];
  assertEquals(pickEditableInfo(infos)?.id, "next");
  assertEquals(pickEditableInfo([...infos].reverse())?.id, "next");
  assertEquals(pickEditableInfo([{ id: "old", attributes: { appStoreState: "REJECTED" } }, infos[0]])?.id, "old");
  assertEquals(pickEditableInfo([infos[0]]), undefined);
});

Deno.test("release: listing-apply runs before store-setup-apply", async () => {
  const mk = await Deno.readTextFile(new URL("../make/store.mk", import.meta.url).pathname);
  const release = mk.slice(mk.indexOf("\nrelease:"));
  const listing = release.indexOf("listing-apply");
  const setup = release.indexOf("store-setup-apply");
  assertEquals(listing > 0 && setup > listing, true);
});
