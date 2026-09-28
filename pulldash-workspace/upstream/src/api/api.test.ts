import { test, expect } from "bun:test";
import api from "./api";

test("credential bridge rejects requests without the workspace header", async () => {
  const response = await api.request("http://127.0.0.1:8790/api/session", {
    headers: { host: "127.0.0.1:8790" },
  });
  expect(response.status).toBe(403);
});
test("credential bridge rejects foreign origins and hosts", async () => {
  for (const headers of [
    { host: "127.0.0.1:8790", origin: "https://example.com" },
    { host: "example.com", origin: "http://127.0.0.1:8790" },
  ]) {
    const response = await api.request("http://127.0.0.1:8790/api/session", {
      headers: { ...headers, "x-dailyglow-client": "workspace" },
    });
    expect(response.status).toBe(403);
  }
});
test("credential bridge rejects unsupported paths before loading credentials", async () => {
  const response = await api.request(
    "http://127.0.0.1:8790/api/github/anything",
    { headers: { host: "127.0.0.1:8790", "x-dailyglow-client": "workspace" } }
  );
  expect(response.status).toBe(400);
});
test("PullDash OAuth endpoints are removed", async () => {
  const response = await api.request(
    "http://127.0.0.1:8790/api/auth/device/code",
    {
      method: "POST",
      headers: { host: "127.0.0.1:8790", "x-dailyglow-client": "workspace" },
    }
  );
  expect(response.status).toBe(404);
});
