import { useEffect, useState } from "react";
import { useTTS } from "../hooks/useTTS";

interface Props { text: string; onClose: () => void; }

export default function PopupBarB({ text, onClose }: Props) {
  const { state, error, play, pause, resume, stop, hide } = useTTS(text, onClose);
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
  const preview = error ? error.slice(0, 55) : text.length > 55 ? text.slice(0, 55) + "\u2026" : text;

  return (
    <div
      data-tauri-drag-region
      style={{
        width: "100%", height: "100%", backgroundColor: "#EFEFEF",
        borderRadius: 999, display: "flex", alignItems: "center",
        padding: "0 16px 0 20px", gap: 16, userSelect: "none",
        fontFamily: "'Space Mono', 'SF Mono', ui-monospace, monospace",
        boxShadow: "0 12px 24px -8px rgba(0,0,0,0.1), 0 4px 8px -4px rgba(0,0,0,0.05), inset 0 1px 0 rgba(255,255,255,0.5)",
        WebkitAppRegion: "drag",
      } as React.CSSProperties}
    >
      {/* Drag indicator */}
      <div style={{ display: "flex", gap: 4, opacity: 0.3, padding: "8px 4px", flexShrink: 0 }}>
        <div style={{ width: 2, height: 16, backgroundColor: "#2C2A29", borderRadius: 2 }} />
        <div style={{ width: 2, height: 16, backgroundColor: "#2C2A29", borderRadius: 2 }} />
      </div>

      {/* Content */}
      <div style={{ flex: 1, display: "flex", flexDirection: "column" as const, justifyContent: "center", gap: 8, minWidth: 0 }}>
        <div style={{
          fontSize: 11, fontWeight: 700, color: "#2C2A29", textTransform: "uppercase" as const,
          letterSpacing: "0.05em", whiteSpace: "nowrap" as const, overflow: "hidden",
          textOverflow: "ellipsis", lineHeight: 1,
        }}>
          {preview}
        </div>
        <div style={{ width: "100%", height: 4, backgroundColor: "#E2DFDD", borderRadius: 2, overflow: "hidden" }}>
          <div style={{
            height: "100%", backgroundColor: "#2C2A29", borderRadius: 2,
            width: isLoading ? "10%" : isDone ? "100%" : isPlaying ? "50%" : "0%",
            transition: "width 0.3s ease",
          }} />
        </div>
      </div>

      {/* Controls */}
      <div style={{ display: "flex", gap: 8, flexShrink: 0, WebkitAppRegion: "no-drag" } as React.CSSProperties}>
        <button
          onClick={() => isPlaying ? pause() : isPaused ? resume() : play()}
          style={{
            height: 36, backgroundColor: "#E2DFDD", border: "none", borderRadius: 999,
            padding: "0 16px", display: "flex", alignItems: "center", gap: 8, cursor: "pointer",
            fontFamily: "inherit", fontSize: 11, fontWeight: 700, color: "#2C2A29",
            textTransform: "uppercase" as const, letterSpacing: "0.05em",
          }}
        >
          <span style={{
            width: 8, height: 8, backgroundColor: isPlaying ? "#D95A2B" : "#aaa",
            borderRadius: "50%", flexShrink: 0, opacity: isPlaying ? 1 : 0.4,
          }} />
          {isLoading ? "..." : isPlaying ? "PAUSE" : isDone ? "REPLAY" : isPaused ? "PLAY" : "PLAY"}
        </button>
        <button
          onClick={() => { stop(); hide(); onClose(); }}
          style={{
            height: 36, backgroundColor: "#E2DFDD", border: "none", borderRadius: 999,
            padding: "0 16px", display: "flex", alignItems: "center", cursor: "pointer",
            fontFamily: "inherit", fontSize: 11, fontWeight: 700, color: "#2C2A29",
            textTransform: "uppercase" as const, letterSpacing: "0.05em",
          }}
        >
          STOP
        </button>
      </div>
    </div>
  );
}
