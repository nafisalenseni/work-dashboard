import { getTimeAgo } from "../lib/relative-time";
import { getPRStatus } from "../lib/pr-status";
import {
  AlertCircle,
  AtSign,
  Check,
  CheckCircle2,
  ChevronDown,
  Circle,
  Clock,
  FileCode,
  Github,
  GitMerge,
  GitPullRequest,
  Loader2,
  MessageSquare,
  RefreshCw,
  User,
  Users,
  X,
  XCircle,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { cn } from "../cn";
import { useAuth } from "../contexts/auth";
import {
  useGitHubReady,
  useGitHubStore,
  usePRList,
  usePRListActions,
  type PRSearchResult,
} from "../contexts/github";
import { useOpenPRReviewTab } from "../contexts/tabs";
import {
  Pagination,
  PaginationContent,
  PaginationItem,
  PaginationLink,
  PaginationNext,
  PaginationPrevious,
} from "../ui/pagination";
import { Skeleton } from "../ui/skeleton";
import { Tooltip, TooltipContent, TooltipTrigger } from "../ui/tooltip";
import { UserHoverCard } from "../ui/user-hover-card";

// ============================================================================
// Types
// ============================================================================

interface FilterConfig {
  mode: "authored" | "review-requested";
  state: "open" | "closed";
}
const STORAGE_KEY = "pulldash_filter_config";
function getFilterConfig(): FilterConfig {
  try {
    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
    return {
      mode:
        (stored.mode ?? stored.repos?.[0]?.mode) === "review-requested"
          ? "review-requested"
          : "authored",
      state: stored.state === "closed" ? "closed" : "open",
    };
  } catch {
    return { mode: "authored", state: "open" };
  }
}
function saveFilterConfig(config: FilterConfig) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
}
function buildSearchQueries(config: FilterConfig): string[] {
  const category =
    config.mode === "authored" ? "author:@me" : "review-requested:@me";
  const state =
    config.state === "closed"
      ? `is:closed closed:>=${new Date(Date.now() - 30 * 86400000).toISOString().slice(0, 10)}`
      : "is:open";
  return [`is:pr archived:false ${state} ${category}`];
}

function extractRepoFromUrl(
  url: string
): { owner: string; repo: string } | null {
  const match = url.match(/repos\/([^/]+)\/([^/]+)/);
  if (match) {
    return { owner: match[1], repo: match[2] };
  }
  return null;
}

// ============================================================================
// Mode Options
// ============================================================================

const STATE_OPTIONS = [
  { value: "open", label: "Open" },
  { value: "closed", label: "Closed" },
] as const;

// ============================================================================
// Main Component
// ============================================================================

export function Home() {
  const openPRReviewTab = useOpenPRReviewTab();
  const { ready: githubReady, error: githubError } = useGitHubReady();
  const { isAuthenticated } = useAuth();

  // Data store
  const prList = usePRList();
  const { fetchPRList, refreshPRList } = usePRListActions();

  const preloadStore = useGitHubStore();
  useEffect(() => {
    if (!githubReady) return;
    const authored = prList.items
      .filter(
        (pr) => pr.user?.login === preloadStore.getState().currentUser?.login
      )
      .slice(0, 5);
    for (const pr of authored) {
      const repo = extractRepoFromUrl(pr.repository_url);
      if (repo) preloadStore.preloadPR(repo.owner, repo.repo, pr.number);
    }
  }, [githubReady, prList.items, preloadStore]);

  // Filter config
  const [config, setConfig] = useState<FilterConfig>(getFilterConfig);

  // Pagination
  const [page, setPage] = useState(1);
  const perPage = 30;

  // Build queries from config (one per mode group)
  const searchQueries = useMemo(() => buildSearchQueries(config), [config]);

  // Save config to localStorage whenever it changes
  useEffect(() => {
    saveFilterConfig(config);
  }, [config]);

  // Fetch PRs when queries or page changes (or when GitHub becomes ready)
  useEffect(() => {
    if (githubReady) {
      fetchPRList(searchQueries, page, perPage);
    }
  }, [fetchPRList, searchQueries, page, perPage, githubReady]);

  // Reset page when config changes
  useEffect(() => {
    setPage(1);
  }, [config.mode, config.state]);

  // Set document title
  useEffect(() => {
    document.title = isAuthenticated ? "Home · Pulldash" : "Pulldash";
  }, [isAuthenticated]);

  // Convenience accessors
  const prs = prList.items;
  const loadingPrs = prList.loading;
  const totalCount = prList.totalCount;

  const handleStateChange = useCallback((state: FilterConfig["state"]) => {
    setConfig((prev) => ({ ...prev, state }));
  }, []);

  const handleOpenPR = useCallback(
    (owner: string, repo: string, number: number) => {
      openPRReviewTab(owner, repo, number);
    },
    [openPRReviewTab]
  );

  const totalPages = Math.max(1, Math.ceil(totalCount / perPage));

  // Show loading/error state while GitHub client initializes
  if (!githubReady) {
    if (githubError) {
      return (
        <div className="h-full bg-background flex items-center justify-center">
          <div className="flex flex-col items-center gap-4">
            <p className="text-destructive font-medium">
              Failed to connect to GitHub
            </p>
            <p className="text-sm text-muted-foreground">{githubError}</p>
          </div>
        </div>
      );
    }
    return <HomeLoadingSkeleton />;
  }

  return (
    <div className="h-full bg-background flex flex-col overflow-hidden">
      {/* Filter Bar */}
      <div className="border-b border-border px-2 sm:px-4 py-2 shrink-0 bg-card/30">
        {/* Mobile: horizontal scroll, Desktop: wrap */}
        <div className="flex items-center gap-2 sm:gap-3 overflow-x-auto hide-scrollbar">
          {/* State Toggle */}
          <div className="flex items-center gap-0.5 p-0.5 rounded-md bg-muted/50 shrink-0">
            {STATE_OPTIONS.map((option) => (
              <button
                key={option.value}
                onClick={() => handleStateChange(option.value)}
                className={cn(
                  "px-2 py-1 text-xs font-medium rounded transition-colors",
                  config.state === option.value
                    ? "bg-background shadow-sm"
                    : "text-muted-foreground hover:text-foreground"
                )}
              >
                {option.label}
              </button>
            ))}
          </div>

          <div
            className="flex items-center gap-2 shrink-0"
            aria-label="Pull request category"
          >
            {(
              [
                { mode: "authored", label: "My PRs", icon: User },
                {
                  mode: "review-requested",
                  label: "Review Requests",
                  icon: AtSign,
                },
              ] as const
            ).map((option) => (
              <button
                key={option.mode}
                type="button"
                aria-pressed={config.mode === option.mode}
                onClick={() => {
                  setPage(1);
                  setConfig((prev) => ({
                    ...prev,
                    mode: option.mode,
                  }));
                }}
                className={cn(
                  "flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-medium transition-colors",
                  config.mode === option.mode
                    ? "bg-muted border-border text-foreground"
                    : "border-transparent text-muted-foreground hover:bg-muted/50"
                )}
              >
                <option.icon className="w-3.5 h-3.5" />
                {option.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 flex overflow-hidden">
        {/* PR List Panel */}
        <div className="flex-1 flex flex-col overflow-hidden">
          {/* Results Header */}
          <div className="flex items-center justify-between px-4 py-2 border-b border-border shrink-0">
            <span className="text-xs text-muted-foreground">
              {loadingPrs && prs.length === 0 ? (
                <span className="flex items-center gap-2">
                  <Loader2 className="w-3 h-3 animate-spin" />
                  Loading...
                </span>
              ) : (
                <span>
                  <span className="font-medium text-foreground">
                    {totalCount.toLocaleString()}
                  </span>{" "}
                  pull requests
                  {config.state === "closed"
                    ? " · closed in the last 30 days"
                    : ""}
                </span>
              )}
            </span>
            <div className="flex items-center gap-2">
              <button
                onClick={refreshPRList}
                disabled={loadingPrs}
                className={cn(
                  "p-1 rounded hover:bg-muted transition-colors text-muted-foreground hover:text-foreground",
                  loadingPrs && "opacity-50"
                )}
                title="Refresh"
              >
                <RefreshCw
                  className={cn("w-3.5 h-3.5", loadingPrs && "animate-spin")}
                />
              </button>
            </div>
          </div>

          {/* PR List */}
          <div className="flex-1 overflow-auto">
            {loadingPrs && prs.length === 0 ? (
              <PRListSkeleton count={8} />
            ) : prs.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-20 text-center">
                <GitPullRequest className="w-12 h-12 text-muted-foreground/30 mb-4" />
                <p className="text-lg font-medium text-muted-foreground">
                  No pull requests found
                </p>
                <p className="text-sm text-muted-foreground/70 mt-1 max-w-md">
                  No PRs match your current filters
                </p>
              </div>
            ) : (
              <div className="divide-y divide-border">
                {prs.map((pr) => (
                  <PRListItem key={pr.id} pr={pr} onSelect={handleOpenPR} />
                ))}
              </div>
            )}
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="border-t border-border px-4 py-3 shrink-0">
              <Pagination>
                <PaginationContent>
                  <PaginationItem>
                    <PaginationPrevious
                      onClick={() => setPage((p) => Math.max(1, p - 1))}
                      className={cn(
                        "cursor-pointer",
                        page === 1 && "pointer-events-none opacity-50"
                      )}
                    />
                  </PaginationItem>

                  {totalPages <= 7 ? (
                    Array.from({ length: totalPages }, (_, i) => (
                      <PaginationItem key={i + 1}>
                        <PaginationLink
                          onClick={() => setPage(i + 1)}
                          isActive={page === i + 1}
                          className="cursor-pointer"
                        >
                          {i + 1}
                        </PaginationLink>
                      </PaginationItem>
                    ))
                  ) : (
                    <>
                      {[1, 2, 3].map((n) => (
                        <PaginationItem key={n}>
                          <PaginationLink
                            onClick={() => setPage(n)}
                            isActive={page === n}
                            className="cursor-pointer"
                          >
                            {n}
                          </PaginationLink>
                        </PaginationItem>
                      ))}
                      {page > 4 && (
                        <PaginationItem>
                          <span className="px-2">...</span>
                        </PaginationItem>
                      )}
                      {page > 3 && page < totalPages - 2 && (
                        <PaginationItem>
                          <PaginationLink isActive className="cursor-pointer">
                            {page}
                          </PaginationLink>
                        </PaginationItem>
                      )}
                      {page < totalPages - 3 && (
                        <PaginationItem>
                          <span className="px-2">...</span>
                        </PaginationItem>
                      )}
                      {[totalPages - 2, totalPages - 1, totalPages]
                        .filter((n) => n > 3)
                        .map((n) => (
                          <PaginationItem key={n}>
                            <PaginationLink
                              onClick={() => setPage(n)}
                              isActive={page === n}
                              className="cursor-pointer"
                            >
                              {n}
                            </PaginationLink>
                          </PaginationItem>
                        ))}
                    </>
                  )}

                  <PaginationItem>
                    <PaginationNext
                      onClick={() =>
                        setPage((p) => Math.min(totalPages, p + 1))
                      }
                      className={cn(
                        "cursor-pointer",
                        page === totalPages && "pointer-events-none opacity-50"
                      )}
                    />
                  </PaginationItem>
                </PaginationContent>
              </Pagination>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ============================================================================
// PR List Item
// ============================================================================

interface PRListItemProps {
  pr: PRSearchResult;
  onSelect: (owner: string, repo: string, number: number) => void;
}

function PRListItem({ pr, onSelect }: PRListItemProps) {
  const preloadStore = useGitHubStore();
  const preload = () => {
    const repo = extractRepoFromUrl(pr.repository_url);
    if (repo) preloadStore.preloadPR(repo.owner, repo.repo, pr.number, true);
  };
  const repoInfo = extractRepoFromUrl(pr.repository_url);
  const isMerged = pr.pull_request?.merged_at != null;
  const isClosed = pr.state === "closed" && !isMerged;

  const handleClick = () => {
    if (repoInfo) {
      onSelect(repoInfo.owner, repoInfo.repo, pr.number);
    }
  };

  const status = getPRStatus(pr);
  const statusColors = {
    red: "border-red-500 text-red-600 bg-red-50",
    blue: "border-blue-500 text-blue-600 bg-blue-50",
    green: "border-green-600 text-green-700 bg-green-50",
  };

  return (
    <button
      onClick={handleClick}
      onMouseEnter={preload}
      onFocus={preload}
      className="w-full flex items-start gap-2 sm:gap-3 px-2 sm:px-4 py-3 hover:bg-muted/50 transition-colors text-left"
    >
      {/* PR Icon */}
      {isMerged ? (
        <GitMerge className="w-4 h-4 mt-0.5 shrink-0 text-purple-500" />
      ) : isClosed ? (
        <GitPullRequest className="w-4 h-4 mt-0.5 shrink-0 text-red-500" />
      ) : (
        <GitPullRequest
          className={cn(
            "w-4 h-4 mt-0.5 shrink-0",
            pr.draft ? "text-muted-foreground" : "text-green-500"
          )}
        />
      )}

      {/* Content */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="font-medium hover:text-blue-400 break-words">
            {pr.title}
          </span>
        </div>
        <div className="text-xs text-muted-foreground/85 mt-1 flex items-center gap-1.5 flex-wrap">
          {repoInfo && (
            <>
              <span className="font-mono truncate max-w-[120px] sm:max-w-none">
                {repoInfo.owner}/{repoInfo.repo}
              </span>
              <span>•</span>
            </>
          )}
          <span>#{pr.number}</span>
          <span className="hidden xs:inline">•</span>
          <time
            className="hidden xs:inline"
            dateTime={pr.created_at}
            title={new Date(pr.created_at).toLocaleString()}
          >
            Opened {getTimeAgo(new Date(pr.created_at))}
          </time>
          {pr.user && (
            <>
              <span className="hidden sm:inline">•</span>
              <UserHoverCard login={pr.user.login}>
                <span className="hover:text-blue-400 hover:underline cursor-pointer hidden sm:inline">
                  {pr.user.login}
                </span>
              </UserHoverCard>
            </>
          )}
          {pr.changedFiles !== undefined && (
            <>
              <span className="hidden sm:inline">•</span>
              <span className="hidden sm:flex items-center gap-1">
                <FileCode className="w-3 h-3" />
                {pr.changedFiles}
              </span>
            </>
          )}
          {(pr.additions !== undefined || pr.deletions !== undefined) && (
            <>
              <span className="hidden sm:inline">•</span>
              <span className="hidden sm:inline">
                <span className="text-green-500">+{pr.additions || 0}</span>{" "}
                <span className="text-red-500">−{pr.deletions || 0}</span>
              </span>
            </>
          )}
        </div>
      </div>
      <div className="w-40 sm:w-44 shrink-0 self-center flex justify-end">
        {status && (
          <span
            className={cn(
              "shrink-0 self-center rounded-full border px-2.5 py-1 text-xs font-medium",
              statusColors[status.tone]
            )}
          >
            {status.label}
          </span>
        )}
      </div>
    </button>
  );
}

// ============================================================================
// Skeleton Components
// ============================================================================

function HomeLoadingSkeleton() {
  return (
    <div className="h-full bg-background flex flex-col overflow-hidden">
      {/* Filter Bar Skeleton */}
      <div className="border-b border-border px-4 py-2 shrink-0 flex items-center gap-3 bg-card/30">
        <Skeleton className="h-7 w-24" />
        <Skeleton className="h-6 w-48" />
        <div className="flex-1" />
        <Skeleton className="h-7 w-24" />
        <Skeleton className="h-7 w-[200px]" />
      </div>

      {/* Main Content */}
      <div className="flex-1 flex overflow-hidden">
        <div className="flex-1 flex flex-col overflow-hidden">
          {/* Results Header Skeleton */}
          <div className="flex items-center justify-between px-4 py-2 border-b border-border shrink-0">
            <Skeleton className="h-4 w-32" />
            <Skeleton className="h-4 w-20" />
          </div>

          {/* PR List Skeleton */}
          <PRListSkeleton count={8} />
        </div>
      </div>
    </div>
  );
}

function PRListSkeleton({ count = 5 }: { count?: number }) {
  return (
    <div className="divide-y divide-border">
      {Array.from({ length: count }).map((_, i) => (
        <PRListItemSkeleton key={i} />
      ))}
    </div>
  );
}

function PRListItemSkeleton() {
  return (
    <div className="flex items-start gap-3 px-4 py-3">
      {/* PR Icon */}
      <Skeleton className="w-4 h-4 mt-0.5 rounded-full shrink-0" />

      {/* Content */}
      <div className="flex-1 min-w-0 space-y-2">
        <div className="flex items-center gap-2">
          <Skeleton className="h-5 w-[60%]" />
          <Skeleton className="h-4 w-12 rounded-full" />
        </div>
        <div className="flex items-center gap-1.5">
          <Skeleton className="h-3 w-32" />
          <Skeleton className="h-3 w-8" />
          <Skeleton className="h-3 w-16" />
          <Skeleton className="h-3 w-20" />
        </div>
      </div>
    </div>
  );
}
