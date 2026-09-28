import { expect, test } from "bun:test";
import { workspaceFetch } from "./workspace-fetch";

test("native bridge preserves API payloads and rejects external URLs", async () => {
  const previous = Object.getOwnPropertyDescriptor(globalThis, "window");
  const messages: unknown[] = [];
  Object.defineProperty(globalThis, "window", {
    configurable: true,
    value: {
      location: new URL("http://127.0.0.1:12345/owner/repo/pull/1"),
      webkit: {
        messageHandlers: {
          dailyglowGitHub: {
            postMessage: async (message: unknown) => {
              messages.push(message);
              return { status: 204, headers: {}, body: "" };
            },
          },
        },
      },
    },
  });
  try {
    const response = await workspaceFetch("/api/github/repos/a/b/pulls/1", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: '{"state":"closed"}',
    });
    expect(response.status).toBe(204);
    expect(await response.text()).toBe("");
    expect(messages).toEqual([
      {
        path: "/api/github/repos/a/b/pulls/1",
        method: "PATCH",
        headers: { "content-type": "application/json" },
        body: '{"state":"closed"}',
      },
    ]);
    await expect(
      workspaceFetch("https://example.com/api/session")
    ).rejects.toThrow("Unsupported workspace request");
    expect(messages.length).toBe(1);
  } finally {
    if (previous) Object.defineProperty(globalThis, "window", previous);
    else Reflect.deleteProperty(globalThis, "window");
  }
});
