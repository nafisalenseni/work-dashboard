import {
  ContextMenu,
  ContextMenuTrigger,
  ContextMenuContent,
  ContextMenuItem,
} from "../ui/context-menu";
import {
  ArrowLeft,
  GitMerge,
  GitPullRequest,
  Home as HomeIcon,
  X,
} from "lucide-react";
import {
  Activity,
  lazy,
  Suspense,
  useCallback,
  useEffect,
  useState,
} from "react";
import { useNavigate, useParams } from "react-router-dom";
import { cn } from "../cn";
import { useAuth } from "../contexts/auth";
import {
  useOpenPRReviewTab,
  useTabContext,
  type Tab,
  type TabStatus,
} from "../contexts/tabs";
import { Home } from "./home";
const PRReviewContent = lazy(() =>
  import("./pr-review").then((module) => ({ default: module.PRReviewContent }))
);

// ============================================================================
// App Shell - Tab-based Layout
// ============================================================================

export function AppShell() {
  const {
    tabs,
    activeTabId,
    activeTab,
    setActiveTab,
    closeTab,
    openTab,
    getExistingPRTab,
  } = useTabContext();
  const { isAuthenticated } = useAuth();
  const params = useParams<{ owner: string; repo: string; number: string }>();
  const navigate = useNavigate();

  // Retain only the three most recently visited PR views. Hidden Activity
  // boundaries preserve DOM/state but suspend effects and keyboard listeners.
  const [recentPRIds, setRecentPRIds] = useState<string[]>([]);
  useEffect(() => {
    if (activeTab?.type !== "pr-review") return;
    setRecentPRIds((ids) =>
      [activeTab.id, ...ids.filter((id) => id !== activeTab.id)].slice(0, 3)
    );
  }, [activeTab?.id, activeTab?.type]);
  const retainedIds = [
    ...new Set([
      ...(activeTab?.type === "pr-review" ? [activeTab.id] : []),
      ...recentPRIds,
    ]),
  ]
    .filter((id) => tabs.some((tab) => tab.id === id))
    .slice(0, 3);

  // URL is the source of truth - sync URL → Tab
  useEffect(() => {
    if (params.owner && params.repo && params.number) {
      const owner = params.owner;
      const repo = params.repo;
      const number = parseInt(params.number, 10);
      const expectedTabId = `pr-${owner}-${repo}-${number}`;

      // Only update if needed
      if (activeTabId === expectedTabId) return;

      // Check if tab already exists
      const existing = getExistingPRTab(owner, repo, number);
      if (existing) {
        setActiveTab(existing.id);
      } else {
        // Create new tab
        openTab({
          id: expectedTabId,
          type: "pr-review",
          label: `#${number}`,
          owner,
          repo,
          number,
        });
      }
    } else {
      // Home route - only switch if not already on home
      if (activeTabId !== "home") {
        setActiveTab("home");
      }
    }
  }, [params.owner, params.repo, params.number]);

  // Navigate when clicking on a tab
  const handleTabSelect = useCallback(
    (tab: Tab) => {
      if (tab.type === "home") {
        navigate("/");
      } else if (
        tab.type === "pr-review" &&
        tab.owner &&
        tab.repo &&
        tab.number
      ) {
        navigate(`/${tab.owner}/${tab.repo}/pull/${tab.number}`);
      }
    },
    [navigate]
  );

  // Handle keyboard shortcuts for tab switching
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Cmd/Ctrl + number to switch tabs
      if ((e.metaKey || e.ctrlKey) && e.key >= "1" && e.key <= "9") {
        e.preventDefault();
        const index = parseInt(e.key) - 1;
        if (tabs[index]) {
          handleTabSelect(tabs[index]);
        }
      }
      // Cmd/Ctrl + W to close current tab
      if ((e.metaKey || e.ctrlKey) && e.key === "w") {
        if (activeTabId !== "home") {
          e.preventDefault();
          closeTab(activeTabId);
        }
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [tabs, activeTabId, handleTabSelect, closeTab]);

  return (
    <div className="h-screen flex flex-col overflow-hidden bg-background">
      <div className="h-9 bg-sidebar flex items-center shrink-0 pl-2 border-b border-border/50 app-drag-region">
        <div className="h-full flex-1 flex items-center gap-0.5 overflow-x-auto hide-scrollbar app-no-drag">
          {tabs.map((tab) =>
            tab.type === "home" ? (
              activeTabId !== tab.id && (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => handleTabSelect(tab)}
                  className="flex items-center gap-1.5 h-7 px-2 text-xs font-medium text-muted-foreground hover:text-foreground hover:bg-muted/60 rounded-md transition-colors shrink-0 focus-visible:outline-2 focus-visible:outline-ring"
                >
                  <ArrowLeft className="w-3.5 h-3.5" />
                  Pull requests
                </button>
              )
            ) : (
              <TabItem
                key={tab.id}
                tab={tab}
                isActive={tab.id === activeTabId}
                onSelect={() => handleTabSelect(tab)}
                onClose={() => closeTab(tab.id)}
              />
            )
          )}
        </div>
        <div className="h-full flex items-center gap-2 pr-2 sm:pr-3 app-no-drag">
          <div className="hidden sm:block">
            <PRUrlInput />
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-hidden relative">
        <div
          className={cn(
            "absolute inset-0",
            activeTabId !== "home" && "invisible pointer-events-none"
          )}
        >
          <Home />
        </div>

        {tabs
          .filter(
            (tab) =>
              retainedIds.includes(tab.id) &&
              tab.type === "pr-review" &&
              tab.owner &&
              tab.repo &&
              tab.number
          )
          .map((tab) => (
            <Activity
              key={tab.id}
              mode={tab.id === activeTabId ? "visible" : "hidden"}
            >
              <div className="absolute inset-0">
                <Suspense
                  fallback={
                    <div
                      role="status"
                      className="p-6 text-sm text-muted-foreground"
                    >
                      Loading pull request…
                    </div>
                  }
                >
                  <PRReviewContent
                    owner={tab.owner!}
                    repo={tab.repo!}
                    number={tab.number!}
                    tabId={tab.id}
                  />
                </Suspense>
              </div>
            </Activity>
          ))}
      </div>
    </div>
  );
}

// ============================================================================
// Tab Item
// ============================================================================

interface TabItemProps {
  tab: Tab;
  isActive: boolean;
  onSelect: () => void;
  onClose: () => void;
}

function TabItem({ tab, isActive, onSelect, onClose }: TabItemProps) {
  const isHome = tab.type === "home";

  const handleClose = useCallback(
    (e: React.MouseEvent) => {
      e.stopPropagation();
      onClose();
    },
    [onClose]
  );

  const handleMiddleClick = useCallback(
    (e: React.MouseEvent) => {
      if (e.button === 1 && !isHome) {
        e.preventDefault();
        onClose();
      }
    },
    [isHome, onClose]
  );

  const tabElement = (
    <div
      role="button"
      tabIndex={0}
      onClick={onSelect}
      onMouseDown={handleMiddleClick}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onSelect();
        }
      }}
      className={cn(
        "group flex items-center gap-2 h-7 px-2 text-xs font-medium rounded-md transition-colors shrink-0 max-w-[180px] cursor-pointer",
        isActive
          ? "bg-background text-foreground shadow-sm ring-1 ring-inset ring-border"
          : "text-muted-foreground hover:text-foreground hover:bg-muted/60"
      )}
    >
      {isHome ? (
        <HomeIcon className="w-4 h-4 shrink-0" />
      ) : tab.status?.state === "merged" ? (
        <GitMerge className="w-3 h-3 shrink-0 text-purple-500" />
      ) : (
        <TabStatusIndicator status={tab.status} />
      )}

      {!isHome && (
        <span className="truncate">{isHome ? "Home" : tab.label}</span>
      )}

      {/* Close button */}
      {!isHome && (
        <button
          onClick={handleClose}
          className={cn(
            "ml-0.5 p-0.5 rounded hover:bg-muted transition-opacity shrink-0",
            isActive
              ? "opacity-60 hover:opacity-100"
              : "opacity-40 hover:opacity-100"
          )}
        >
          <X className="w-3 h-3" />
        </button>
      )}
    </div>
  );
  const [copyStatus, setCopyStatus] = useState("");
  useEffect(() => {
    if (!copyStatus) return;
    const timer = setTimeout(() => setCopyStatus(""), 2500);
    return () => clearTimeout(timer);
  }, [copyStatus]);

  if (isHome || !tab.owner || !tab.repo || !tab.number) return tabElement;
  const url = `https://github.com/${encodeURIComponent(tab.owner)}/${encodeURIComponent(tab.repo)}/pull/${tab.number}`;
  return (
    <>
      <ContextMenu>
        <ContextMenuTrigger asChild>{tabElement}</ContextMenuTrigger>
        <ContextMenuContent>
          <ContextMenuItem
            onSelect={() => {
              void navigator.clipboard.writeText(url).then(
                () => setCopyStatus("PR link copied"),
                () =>
                  setCopyStatus(
                    "Could not copy link. Check clipboard permissions."
                  )
              );
            }}
          >
            Copy PR link
          </ContextMenuItem>
        </ContextMenuContent>
      </ContextMenu>
      {copyStatus && (
        <div
          role="status"
          className="fixed bottom-4 right-4 z-50 rounded-md border border-border bg-popover px-3 py-2 text-sm text-popover-foreground shadow-md"
        >
          {copyStatus}
        </div>
      )}
    </>
  );
}

// ============================================================================
// Status Indicator
// ============================================================================

function TabStatusIndicator({ status }: { status?: TabStatus }) {
  if (!status) {
    // Loading state - show pulsing dot
    return (
      <span className="w-2 h-2 rounded-full bg-muted-foreground/50 animate-pulse shrink-0" />
    );
  }

  // Determine the color based on state and checks
  let colorClass = "bg-muted-foreground/50"; // default/unknown
  let title = "Unknown";

  if (status.state === "closed") {
    colorClass = "bg-red-500";
    title = "Closed";
  } else if (status.state === "draft") {
    colorClass = "bg-muted-foreground";
    title = "Draft";
  } else if (status.state === "open") {
    // Open PR - color based on checks and mergeability
    if (status.mergeable === false) {
      colorClass = "bg-red-500";
      title = "Has conflicts";
    } else if (status.checks === "failure") {
      colorClass = "bg-red-500";
      title = "Checks failing";
    } else if (status.checks === "pending") {
      colorClass = "bg-yellow-500";
      title = "Checks running";
    } else if (status.checks === "success" || status.checks === "none") {
      colorClass = "bg-green-500";
      title = status.mergeable ? "Ready to merge" : "Checks passed";
    }
  }

  return (
    <span
      className={cn("w-2 h-2 rounded-full shrink-0", colorClass)}
      title={title}
    />
  );
}

// ============================================================================
// PR URL Input
// ============================================================================

function PRUrlInput() {
  const openPRReviewTab = useOpenPRReviewTab();
  const [prUrl, setPrUrl] = useState("");

  const handleSubmit = useCallback(
    (e: React.FormEvent) => {
      e.preventDefault();
      const url = prUrl.trim();
      if (!url) return;

      const match = url.match(/github\.com\/([^/]+)\/([^/]+)\/pull\/(\d+)/);
      if (match) {
        const [, owner, repo, number] = match;
        openPRReviewTab(owner, repo, parseInt(number, 10));
        setPrUrl("");
      }
    },
    [prUrl, openPRReviewTab]
  );

  return (
    <form onSubmit={handleSubmit} className="max-w-[180px]">
      <div className="relative">
        <input
          type="text"
          value={prUrl}
          onChange={(e) => setPrUrl(e.target.value)}
          placeholder="PR URL..."
          className="w-full h-6 pl-6 pr-2 rounded-md border border-border/50 bg-white/5 text-[11px] placeholder:text-muted-foreground/50 focus:outline-none focus:ring-1 focus:ring-ring focus:border-transparent font-mono"
        />
        <GitPullRequest className="absolute left-1.5 top-1/2 -translate-y-1/2 w-3 h-3 text-muted-foreground/50" />
      </div>
    </form>
  );
}
