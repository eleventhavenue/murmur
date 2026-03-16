import { useEffect, useState } from "react";
import { listen } from "@tauri-apps/api/event";
import PopupBar from "./components/PopupBar";
import { HotkeyPayload } from "./lib/types";

function App() {
  const [text, setText] = useState<string | null>(null);

  useEffect(() => {
    const unlisten = listen<HotkeyPayload>("hotkey-triggered", (event) => {
      setText(event.payload.text);
    });

    const unlistenEmpty = listen("hotkey-empty", () => {
      setText(null);
    });

    return () => {
      unlisten.then((fn) => fn());
      unlistenEmpty.then((fn) => fn());
    };
  }, []);

  if (!text) return null;

  return <PopupBar text={text} onClose={() => setText(null)} />;
}

export default App;
