import { useGitHubSelector, useGitHubStore } from "@/browser/contexts/github";
import { useEffect } from "react";
import { usePRReviewStore } from ".";

export function useCurrentUserLoader() {
  const store = usePRReviewStore();
  const github = useGitHubStore();
  const ready = useGitHubSelector((s) => s.ready);
  const currentUser = github.getState().currentUser?.login ?? null;

  useEffect(() => {
    if (ready && currentUser) {
      store.setCurrentUser(currentUser);
    }
  }, [ready, currentUser, store]);
}
