import { useEffect, useState } from "react";
import { listen } from "@tauri-apps/api/event";
import PopupBarA from "./components/PopupBarA";
import PopupBarB from "./components/PopupBarB";
import PopupBarC from "./components/PopupBarC";
import { HotkeyPayload } from "./lib/types";

const designs = ["A", "B", "C"] as const;
type Design = (typeof designs)[number];

function App() {
  const [text, setText] = useState<string | null>(null);
  const [design, setDesign] = useState<Design>(() => {
    // Load saved preference, default to C
    try { return (localStorage.getItem("murmur-design") as Design) || "C"; } catch { return "C"; }
  });

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

  // Listen for design change from tray menu or settings
  useEffect(() => {
    const unlisten = listen<{ design: string }>("design-changed", (event) => {
      const d = event.payload.design as Design;
      if (designs.includes(d)) {
        setDesign(d);
        try { localStorage.setItem("murmur-design", d); } catch {}
      }
    });
    return () => { unlisten.then((fn) => fn()); };
  }, []);

  if (!text) return null;

  const onClose = () => setText(null);

  return (
    <>
      {design === "A" && <PopupBarA text={text} onClose={onClose} />}
      {design === "B" && <PopupBarB text={text} onClose={onClose} />}
      {design === "C" && <PopupBarC text={text} onClose={onClose} />}
    </>
  );
}

export default App;
