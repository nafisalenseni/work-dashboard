import { defineConfig } from "vite";
import { readFileSync } from "node:fs";

export default defineConfig(({ command }) => ({
  base: "./",
  define: command === "build" ? { "process.env.NODE_ENV": JSON.stringify("production") } : {},
  build: {
    outDir: "../Dailyglow/NotesEditorWeb",
    emptyOutDir: true,
    // A classic bundle works with WKWebView's local file loading.
    lib: {
      entry: "src/main.tsx",
      name: "DailyGlowNotes",
      formats: ["iife"],
      fileName: () => "editor.js",
      cssFileName: "editor",
    },
  },
  plugins: [{
    name: "app-html",
    generateBundle() {
      const html = readFileSync(new URL("./index.html", import.meta.url), "utf8")
        .replace('<script type="module" src="/src/main.tsx"></script>', '<script src="./editor.js" defer></script>')
        .replace("</head>", '<link rel="stylesheet" href="./editor.css" />\n</head>');
      this.emitFile({ type: "asset", fileName: "index.html", source: html });
    },
  }],
}));
