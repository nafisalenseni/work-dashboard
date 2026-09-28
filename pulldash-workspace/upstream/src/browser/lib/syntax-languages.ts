import { refractor } from "refractor/core";
export { refractor };

// Explicit imports let the browser build emit independently loaded grammar chunks.
const loaders = {
  bash: () => import("refractor/bash"),
  c: () => import("refractor/c"),
  clojure: () => import("refractor/clojure"),
  cpp: () => import("refractor/cpp"),
  csharp: () => import("refractor/csharp"),
  css: () => import("refractor/css"),
  dart: () => import("refractor/dart"),
  elixir: () => import("refractor/elixir"),
  elm: () => import("refractor/elm"),
  erlang: () => import("refractor/erlang"),
  fsharp: () => import("refractor/fsharp"),
  go: () => import("refractor/go"),
  graphql: () => import("refractor/graphql"),
  groovy: () => import("refractor/groovy"),
  haskell: () => import("refractor/haskell"),
  ini: () => import("refractor/ini"),
  java: () => import("refractor/java"),
  javascript: () => import("refractor/javascript"),
  json: () => import("refractor/json"),
  jsx: () => import("refractor/jsx"),
  kotlin: () => import("refractor/kotlin"),
  latex: () => import("refractor/latex"),
  less: () => import("refractor/less"),
  lisp: () => import("refractor/lisp"),
  lua: () => import("refractor/lua"),
  markdown: () => import("refractor/markdown"),
  markup: () => import("refractor/markup"),
  objectivec: () => import("refractor/objectivec"),
  ocaml: () => import("refractor/ocaml"),
  perl: () => import("refractor/perl"),
  php: () => import("refractor/php"),
  protobuf: () => import("refractor/protobuf"),
  python: () => import("refractor/python"),
  r: () => import("refractor/r"),
  ruby: () => import("refractor/ruby"),
  rust: () => import("refractor/rust"),
  sass: () => import("refractor/sass"),
  scala: () => import("refractor/scala"),
  scss: () => import("refractor/scss"),
  sql: () => import("refractor/sql"),
  swift: () => import("refractor/swift"),
  toml: () => import("refractor/toml"),
  tsx: () => import("refractor/tsx"),
  typescript: () => import("refractor/typescript"),
  vbnet: () => import("refractor/vbnet"),
  vim: () => import("refractor/vim"),
  yaml: () => import("refractor/yaml"),
  zig: () => import("refractor/zig"),
};
const pending = new Map<string, Promise<void>>();
export async function ensureLanguage(language: string): Promise<void> {
  if (refractor.registered(language)) return;
  const loader = loaders[language as keyof typeof loaders];
  if (!loader) return;
  let request = pending.get(language);
  if (!request) {
    request = loader().then((module) => {
      refractor.register(module.default);
    });
    pending.set(language, request);
  }
  try {
    await request;
  } catch {
    /* Plain escaped text remains available if a grammar fails to load. */
  } finally {
    if (pending.get(language) === request) pending.delete(language);
  }
}
