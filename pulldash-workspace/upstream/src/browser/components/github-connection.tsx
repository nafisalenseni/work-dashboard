import { useAuth } from "../contexts/auth";

export function ConnectionStatus() {
  const { login, isLoading, error, reconnect } = useAuth();
  return (
    <div className="px-3 py-2 text-xs text-muted-foreground border-b border-border flex items-center gap-3">
      <span>
        {isLoading
          ? "Connecting to Dailyglow’s GitHub session…"
          : error || `Connected as ${login} · GitHub CLI`}
      </span>
      {!isLoading && error && (
        <button className="underline" onClick={reconnect}>
          Retry connection
        </button>
      )}
    </div>
  );
}
export function UserMenuButton() {
  const { login } = useAuth();
  return (
    <span
      className="text-xs text-muted-foreground"
      title="Uses the same GitHub CLI login as Dailyglow"
    >
      {login ? `@${login}` : "GitHub disconnected"}
    </span>
  );
}
