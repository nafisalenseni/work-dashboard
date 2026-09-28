import { createRoot } from "react-dom/client";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import { AppShell } from "./components/app-shell";
import { CommandPaletteProvider } from "./components/command-palette";
import { AuthProvider, ConnectionGate } from "./contexts/auth";
import { GitHubProvider } from "./contexts/github";
import { TabProvider } from "./contexts/tabs";
import "./index.css";

createRoot(document.getElementById("app")!).render(
  <AuthProvider>
    <ConnectionGate>
      <GitHubProvider>
        <BrowserRouter>
          <TabProvider>
            <CommandPaletteProvider>
              <Routes>
                {/* Home */}
                <Route path="/" element={<AppShell />} />
                {/* PR review - URL like /:owner/:repo/pull/:number */}
                <Route
                  path="/:owner/:repo/pull/:number"
                  element={<AppShell />}
                />
              </Routes>
            </CommandPaletteProvider>
          </TabProvider>
        </BrowserRouter>
      </GitHubProvider>
    </ConnectionGate>
  </AuthProvider>
);
