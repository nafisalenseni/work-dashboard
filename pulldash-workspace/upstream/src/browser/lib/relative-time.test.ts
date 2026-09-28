import { test, expect } from "bun:test";
import { getTimeAgo } from "./relative-time";
test("rounds PR ages without truncating a nearly complete day", () => {
  const now = new Date("2026-09-27T18:15:01Z");
  expect(getTimeAgo(new Date("2026-09-25T20:27:59Z"), now)).toBe("2 days ago");
  expect(getTimeAgo(new Date("2026-09-22T03:45:15Z"), now)).toBe("last week");
  expect(getTimeAgo(now, now)).toBe("just now");
});
