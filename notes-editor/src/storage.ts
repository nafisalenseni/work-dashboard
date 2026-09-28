import type { Block, PartialBlock } from "@blocknote/core";

declare global {
  interface Window {
    dailyGlowSavedDocument?: string;
    webkit?: {
      messageHandlers?: {
        blockNoteDocument?: { postMessage: (document: string) => void };
      };
    };
  }
}

const browserStorageKey = "dailyglow.notes.preview";
const nativeHandler = () => window.webkit?.messageHandlers?.blockNoteDocument;

export function loadDocument(): PartialBlock[] | undefined {
  try {
    let json: string | null;
    if (nativeHandler()) {
      const encoded = window.dailyGlowSavedDocument;
      if (!encoded) return undefined;
      const bytes = Uint8Array.from(atob(encoded), character => character.charCodeAt(0));
      json = new TextDecoder().decode(bytes);
    } else {
      json = localStorage.getItem(browserStorageKey);
    }
    return json ? JSON.parse(json) : undefined;
  } catch (error) {
    console.error("Could not restore saved notes", error);
    return undefined;
  }
}

export function saveDocument(document: Block[]): void {
  const json = JSON.stringify(document);
  const handler = nativeHandler();
  if (handler) handler.postMessage(json);
  else localStorage.setItem(browserStorageKey, json);
}
