import { test, expect } from "bun:test";
import { ensureLanguage, refractor } from "./syntax-languages";

test("grammars load on demand, including dependencies and concurrent requests", async () => {
  expect(refractor.registered("yaml")).toBe(false);
  await Promise.all([
    ensureLanguage("yaml"),
    ensureLanguage("yaml"),
    ensureLanguage("tsx"),
  ]);
  expect(refractor.registered("yaml")).toBe(true);
  expect(refractor.registered("tsx")).toBe(true);
  expect(
    refractor
      .highlight("enabled: true", "yaml")
      .children.some((node) => node.type === "element")
  ).toBe(true);
  expect(
    refractor
      .highlight("const view = <div />", "tsx")
      .children.some((node) => node.type === "element")
  ).toBe(true);
  await ensureLanguage("unsupported-language");
  expect(refractor.registered("unsupported-language")).toBe(false);
});
