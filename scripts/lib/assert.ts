// A minimal assertEquals for the Deno tests, from node:assert so the tests need no network or package registry.
import { deepStrictEqual } from "node:assert";

export function assertEquals(actual: unknown, expected: unknown, message?: string): void {
  deepStrictEqual(actual, expected, message);
}
