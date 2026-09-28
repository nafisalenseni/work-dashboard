type NativeReply = {
  status: number;
  headers: Record<string, string>;
  body: string;
};
declare global {
  interface Window {
    webkit?: {
      messageHandlers?: {
        dailyglowGitHub?: { postMessage(body: unknown): Promise<NativeReply> };
      };
    };
  }
}
export async function workspaceFetch(
  input: RequestInfo | URL,
  init?: RequestInit
): Promise<Response> {
  const bridge = window.webkit?.messageHandlers?.dailyglowGitHub;
  if (!bridge) return fetch(input, init);
  const url = new URL(
    input instanceof Request ? input.url : String(input),
    window.location.href
  );
  if (
    url.origin !== window.location.origin ||
    !url.pathname.startsWith("/api/")
  )
    throw new Error("Unsupported workspace request");
  const reply = await bridge.postMessage({
    path: url.pathname + url.search,
    method: init?.method || "GET",
    headers: Object.fromEntries(new Headers(init?.headers)),
    body: init?.body ? String(init.body) : null,
  });
  return new Response([204, 304].includes(reply.status) ? null : reply.body, {
    status: reply.status,
    headers: reply.headers,
  });
}
