import { createRoot } from "react-dom/client";
import "@blocknote/mantine/style.css";
import "./styles.css";
import NotesEditor from "./NotesEditor";
import { loadDocument, saveDocument } from "./storage";

const onReady = () => document.getElementById("loading")?.remove();

createRoot(document.getElementById("root")!).render(
  <NotesEditor initialContent={loadDocument()} onChange={saveDocument} onReady={onReady} />
);
