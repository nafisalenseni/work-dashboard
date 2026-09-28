import { workspaceFetch } from "../lib/workspace-fetch";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";

interface Connection {
  isAuthenticated: boolean;
  isLoading: boolean;
  canWrite: boolean;
  login: string | null;
  error: string | null;
  reconnect: () => Promise<void>;
  disconnect: () => void;
  setRateLimited: (limited: boolean) => void;
}
const AuthContext = createContext<Connection | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [login, setLogin] = useState<string | null>(null);
  const [isLoading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const reconnect = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await workspaceFetch("/api/session", {
        headers: { "X-Dailyglow-Client": "workspace" },
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.message);
      setLogin(data.login);
    } catch (error) {
      setLogin(null);
      setError(
        error instanceof Error
          ? error.message
          : "Could not connect to GitHub CLI"
      );
    } finally {
      setLoading(false);
    }
  }, []);
  const disconnect = useCallback(() => {
    setLogin(null);
    setError("GitHub session expired. Check gh auth status, then retry.");
  }, []);
  const setRateLimited = useCallback((limited: boolean) => {
    if (limited) setError("GitHub rate limit reached. Wait before retrying.");
  }, []);
  useEffect(() => {
    // Remove credentials left by the original PullDash login implementation.
    for (const key of [
      "pulldash_github_token",
      "pulldash_github_token_expiry",
      "pulldash_anonymous_mode",
    ])
      localStorage.removeItem(key);
    void reconnect();
  }, [reconnect]);
  return (
    <AuthContext.Provider
      value={{
        login,
        isLoading,
        error,
        reconnect,
        disconnect,
        setRateLimited,
        isAuthenticated: !!login,
        canWrite: !!login,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}
export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error("Missing GitHub connection provider");
  return value;
}
export function useCanWrite() {
  return useAuth().canWrite;
}

export function ConnectionGate({ children }: { children: ReactNode }) {
  const { isAuthenticated, isLoading, error, reconnect } = useAuth();
  if (isAuthenticated) return <>{children}</>;
  return (
    <div className="flex min-h-screen items-center justify-center p-8">
      <div className="max-w-md space-y-4">
        <h1 className="text-xl font-semibold">Connect GitHub</h1>
        {isLoading ? (
          <p>Connecting to your GitHub account…</p>
        ) : (
          <>
            <p>
              {error || "Sign in with GitHub CLI to load your pull requests."}
            </p>
            <p>
              Run <code>gh auth login</code> in Terminal, then retry.
            </p>
            <button
              className="rounded-lg border px-4 py-2"
              onClick={() => void reconnect()}
            >
              Retry connection
            </button>
          </>
        )}
      </div>
    </div>
  );
}
