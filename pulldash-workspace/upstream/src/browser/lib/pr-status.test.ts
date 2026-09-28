import { test, expect } from "bun:test";
import { getPRStatus } from "./pr-status";
const open = {
  state: "open",
  draft: false,
  reviewDecision: "APPROVED" as const,
  ciStatus: "success" as const,
};
test("approved passing PR is ready; failures take priority", () => {
  expect(getPRStatus(open)?.label).toBe("Ready to merge");
  expect(getPRStatus({ ...open, ciStatus: "failure" })?.label).toBe(
    "Fix failed checks"
  );
});
test("unapproved open PR waits for review", () => {
  expect(
    getPRStatus({ ...open, reviewDecision: "REVIEW_REQUIRED" })?.label
  ).toBe("Waiting for review");
});
test("drafts, closed PRs, unknown and pending checks are never ready", () => {
  for (const pr of [
    { ...open, draft: true },
    { ...open, state: "closed" },
    { ...open, ciStatus: "pending" as const },
    { ...open, ciStatus: undefined },
  ])
    expect(getPRStatus(pr)).toBeNull();
  expect(getPRStatus({ ...open, draft: true, ciStatus: "failure" })).toBeNull();
});
