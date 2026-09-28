import type { PRSearchResult } from "../contexts/github";

type StatusInput = Pick<
  PRSearchResult,
  "state" | "draft" | "ciStatus" | "reviewDecision" | "pull_request"
>;
export function getPRStatus(
  pr: StatusInput
): { label: string; tone: "red" | "blue" | "green" } | null {
  if (pr.draft || pr.state !== "open" || pr.pull_request?.merged_at)
    return null;
  if (pr.ciStatus === "failure")
    return { label: "Fix failed checks", tone: "red" };
  if (pr.reviewDecision === "APPROVED") {
    return pr.ciStatus === "success"
      ? { label: "Ready to merge", tone: "green" }
      : null;
  }
  // Wait for review metadata rather than guessing while enrichment loads.
  if (pr.reviewDecision === undefined) return null;
  return { label: "Waiting for review", tone: "blue" };
}
