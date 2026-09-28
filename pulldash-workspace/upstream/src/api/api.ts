import { Hono } from "hono";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { existsSync } from "node:fs";

const exec = promisify(execFile);
const localOrigin = "http://127.0.0.1:8790";

async function githubToken() {
  const executable = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"].find(
    existsSync
  );
  if (!executable) throw new Error("GitHub CLI is unavailable");
  const { stdout } = await exec(
    executable,
    ["auth", "token", "--hostname", "github.com"],
    {
      timeout: 10000,
      env: { ...process.env, GH_PROMPT_DISABLED: "1" },
    }
  );
  if (!stdout.trim()) throw new Error("GitHub CLI is not connected");
  return stdout.trim();
}

const api = new Hono().basePath("/api");
// Protect the credentialed local bridge from cross-site requests and DNS rebinding.
api.use("*", async (c, next) => {
  const origin = c.req.header("origin");
  if (
    c.req.header("host") !== "127.0.0.1:8790" ||
    (origin && origin !== localOrigin) ||
    c.req.header("x-dailyglow-client") !== "workspace" ||
    c.req.header("sec-fetch-site") === "cross-site"
  ) {
    return c.json({ message: "Local workspace requests only" }, 403);
  }
  c.header("Cache-Control", "no-store");
  await next();
});

async function githubRequest(path: string, init: RequestInit = {}) {
  const token = await githubToken();
  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer ${token}`);
  headers.set("User-Agent", "Dailyglow-Workspace");
  return fetch(`https://api.github.com/${path}`, {
    ...init,
    headers,
    redirect: "error",
    signal: AbortSignal.timeout(30000),
  });
}

api.get("/session", async (c) => {
  try {
    const response = await githubRequest("user");
    if (!response.ok)
      return c.json(
        {
          message:
            "GitHub CLI session needs attention. Run gh auth login, then retry.",
        },
        401
      );
    const user = (await response.json()) as { login: string };
    return c.json({ login: user.login });
  } catch {
    return c.json(
      {
        message:
          "Could not connect through GitHub CLI. Check gh auth status, then retry.",
      },
      503
    );
  }
});

api.all("/github/*", async (c) => {
  const url = new URL(c.req.url);
  const path = url.pathname.slice("/api/github/".length);
  if (
    !/^(user(?:\/|$)|repos\/|search\/|graphql$|users\/|orgs\/)/.test(path) ||
    path.includes("..") ||
    /%2f|%5c|%2e/i.test(path)
  ) {
    return c.json({ message: "Unsupported GitHub API path" }, 400);
  }
  try {
    const headers = new Headers();
    for (const name of [
      "accept",
      "content-type",
      "x-github-api-version",
      "if-none-match",
    ]) {
      const value = c.req.header(name);
      if (value) headers.set(name, value);
    }
    const response = await githubRequest(path + url.search, {
      method: c.req.method,
      headers,
      body: ["GET", "HEAD"].includes(c.req.method)
        ? undefined
        : await c.req.text(),
    });
    const resultHeaders = new Headers({ "Cache-Control": "no-store" });
    for (const name of [
      "content-type",
      "x-ratelimit-remaining",
      "x-ratelimit-reset",
      "retry-after",
      "etag",
    ]) {
      const value = response.headers.get(name);
      if (value) resultHeaders.set(name, value);
    }
    return new Response(response.body, {
      status: response.status,
      headers: resultHeaders,
    });
  } catch {
    return c.json(
      {
        message:
          "GitHub request failed. Check the GitHub CLI connection and retry.",
      },
      502
    );
  }
});

export default api;
export type AppType = typeof api;
