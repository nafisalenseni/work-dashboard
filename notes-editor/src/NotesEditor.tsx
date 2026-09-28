import { useEffect } from "react";
import type { Block, PartialBlock } from "@blocknote/core";
import { useCreateBlockNote } from "@blocknote/react";
import { BlockNoteView } from "@blocknote/mantine";

type NotesEditorProps = {
  initialContent?: PartialBlock[];
  onChange: (document: Block[]) => void;
  onReady: () => void;
};

export default function NotesEditor({ initialContent, onChange, onReady }: NotesEditorProps) {
  const editor = useCreateBlockNote({ initialContent });

  useEffect(onReady, [onReady]);

  return (
    <BlockNoteView
      editor={editor}
      theme="light"
      onChange={() => onChange(editor.document)}
    />
  );
}
