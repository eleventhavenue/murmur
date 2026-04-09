import { useEffect, useState } from "react";
import { useTTS } from "../hooks/useTTS";

interface Props { text: string; onClose: () => void; }

export default function PopupBarA({ text, onClose }: Props) {
  const { state, error, speed, play, pause, resume, stop, hide, cycleSpeed } = useTTS(text, onClose);
  const [, setElapsed] = useState(0);


  useEffect(() => { if (text && !error) play(); }, [text]); // eslint-disable-line
  useEffect(() => {
    if (state.status !== "playing") return;
    const i = setInterval(() => setElapsed((t) => t + 1), 1000);
    return () => clearInterval(i);
  }, [state.status]);

  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === "Escape") { hide(); onClose(); } };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, []); // eslint-disable-line

  const isPlaying = state.status === "playing";
  const isPaused = state.status === "paused";
  const isLoading = state.status === "loading";
  const isDone = state.status === "idle" && state.progress === 100;
  const preview = error ? error.slice(0, 60) : text.length > 60 ? text.slice(0, 60) + "\u2026" : text;

  return (
    <div
      data-tauri-drag-region
      style={{
        width: "100%", height: "100%", backgroundColor: "#EBEBEB",
        display: "flex", alignItems: "center", padding: "0 24px",
        boxShadow: "0 20px 40px rgba(0,0,0,0.08)", userSelect: "none",
        fontFamily: "'Space Mono', 'Courier New', monospace", color: "#333",
        position: "relative",
        WebkitAppRegion: "drag",
      } as React.CSSProperties}
    >
      {/* Brand */}
      <div style={{ flexShrink: 0, width: 80, fontSize: 11, letterSpacing: "0.12em", opacity: 0.7, textTransform: "lowercase" as const }}>
        murmur
      </div>

      {/* Content */}
      <div style={{ flexGrow: 1, overflow: "hidden", whiteSpace: "nowrap" as const, marginRight: 32 }}>
        <span style={{ fontSize: 11, opacity: 0.5, letterSpacing: "0.12em", marginRight: 8, textTransform: "lowercase" as const }}>
          {isLoading ? "loading:" : isPlaying ? "reading:" : isDone ? "done:" : isPaused ? "paused:" : "ready:"}
        </span>
        <span style={{ fontSize: 11, opacity: 0.9 }}>{preview}</span>
      </div>

      {/* Controls */}
      <div style={{ display: "flex", gap: 16, flexShrink: 0, WebkitAppRegion: "no-drag" } as React.CSSProperties}>
        <button
          onClick={() => isPlaying ? pause() : isPaused ? resume() : play()}
          style={{
            background: "none", border: `1px solid ${isPlaying || isLoading ? "#333" : "transparent"}`,
            color: "#333", fontFamily: "inherit", fontSize: 11, letterSpacing: "0.12em",
            textTransform: "lowercase" as const, padding: "6px 8px", cursor: "pointer",
          }}
        >
          {isLoading ? ".." : isPlaying ? "pa" : "pl"}
        </button>
        <button
          onClick={() => { stop(); hide(); onClose(); }}
          style={{
            background: "none", border: "1px solid transparent",
            color: "#333", fontFamily: "inherit", fontSize: 11, letterSpacing: "0.12em",
            textTransform: "lowercase" as const, padding: "6px 8px", cursor: "pointer",
          }}
        >
          st
        </button>
        <button
          onClick={cycleSpeed}
          style={{
            background: "none", border: "none", color: "#333", fontFamily: "inherit",
            fontSize: 11, letterSpacing: "0.12em", padding: "6px 4px", cursor: "pointer", opacity: 0.5,
          }}
        >
          {speed}x
        </button>
      </div>

      {/* Progress bar */}
      <div style={{ position: "absolute", bottom: 0, left: 0, width: "100%", height: 2, background: "rgba(51,51,51,0.1)" }}>
        <div style={{
          height: "100%", backgroundColor: "#333",
          width: isLoading ? "15%" : isDone ? "100%" : isPlaying ? "50%" : "0%",
          transition: "width 0.3s ease",
        }} />
      </div>
    </div>
  );
}
