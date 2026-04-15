import { useEffect, useState } from "react";
import { useTTS } from "../hooks/useTTS";

interface Props { text: string; onClose: () => void; }

export default function PopupBarC({ text, onClose }: Props) {
  const { state, error, speed, play, pause, resume, stop, hide, cycleSpeed, skipForward, skipBack } = useTTS(text, onClose);
  const [hoveredBtn, setHoveredBtn] = useState<string | null>(null);

  useEffect(() => { if (text && !error) play(); }, [text]); // eslint-disable-line

  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if (e.key === "Escape") { hide(); onClose(); }
      if (e.key === "ArrowRight") skipForward(15);
      if (e.key === "ArrowLeft") skipBack(15);
      if (e.key === " ") {
        e.preventDefault();
        if (state.status === "playing") pause();
        else if (state.status === "paused") resume();
      }
    };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, [state.status]); // eslint-disable-line

  const isPlaying = state.status === "playing";
  const isPaused = state.status === "paused";
  const isLoading = state.status === "loading";
  const isDone = state.status === "idle" && state.progress === 100;
  const preview = error ? error.slice(0, 45) : text.length > 45 ? text.slice(0, 45) + "\u2026" : text;
  const statusText = isLoading ? "Loading" : isPlaying ? "Reading" : isPaused ? "Paused" : isDone ? "Done" : "Ready";

  const btn = (id: string, w = 32): React.CSSProperties => ({
    width: w, height: 32, background: hoveredBtn === id ? "#EAEAEA" : "#FFF",
    border: "1px solid rgba(0,0,0,0.06)", borderRadius: 6,
    boxShadow: "0 1px 2px rgba(0,0,0,0.04)", display: "flex",
    alignItems: "center", justifyContent: "center", color: "#1F2937",
    cursor: "pointer", transition: "all 0.12s ease", padding: 0,
  });

  return (
    <div
      data-tauri-drag-region
      style={{
        width: "100%", height: "100%", background: "#F4F5F7",
        borderRadius: 12, display: "flex", alignItems: "center",
        position: "relative", overflow: "hidden",
        boxShadow: "0 12px 32px rgba(0,0,0,0.1), 0 4px 8px rgba(0,0,0,0.04)",
        border: "1px solid rgba(0,0,0,0.04)",
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
        WebkitAppRegion: "drag",
      } as React.CSSProperties}
    >
      {/* Progress */}
      <div style={{ position: "absolute", bottom: 0, left: 0, width: "100%", height: 3, background: "rgba(0,0,0,0.05)", zIndex: 10 }}>
        <div style={{
          height: "100%", background: "#1F2937", borderRadius: "0 2px 2px 0",
          width: isLoading ? "10%" : isDone ? "100%" : isPlaying ? "50%" : isPaused ? "35%" : "0%",
          transition: "width 0.3s ease",
        }} />
      </div>

      <div style={{ display: "flex", alignItems: "center", width: "100%", height: "100%", padding: "0 10px", gap: 8 }}>
        {/* Drag handle */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", width: 20, height: 32, color: "#9CA3AF", flexShrink: 0 }}>
          <svg width="8" height="14" viewBox="0 0 10 16" fill="currentColor">
            <circle cx="2" cy="2" r="1.5" /><circle cx="8" cy="2" r="1.5" />
            <circle cx="2" cy="8" r="1.5" /><circle cx="8" cy="8" r="1.5" />
            <circle cx="2" cy="14" r="1.5" /><circle cx="8" cy="14" r="1.5" />
          </svg>
        </div>

        {/* Text */}
        <div style={{ flexGrow: 1, display: "flex", flexDirection: "column" as const, justifyContent: "center", minWidth: 0, gap: 1 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 10, fontWeight: 600, textTransform: "uppercase" as const, letterSpacing: "0.5px", color: "#6B7280" }}>
            {isPlaying && (
              <div style={{ display: "flex", alignItems: "flex-end", gap: 1.5, height: 9 }}>
                {[0, 0.15, 0.3].map((d, i) => (
                  <div key={i} style={{
                    width: 2, background: "currentColor", borderRadius: 1,
                    height: [3, 9, 5][i],
                    animation: "wave 1s ease-in-out infinite",
                    animationDelay: `${d}s`,
                  }} />
                ))}
              </div>
            )}
            {statusText}
          </div>
          <div style={{ fontSize: 13, fontWeight: 500, color: "#1F2937", whiteSpace: "nowrap" as const, overflow: "hidden", textOverflow: "ellipsis", lineHeight: 1.2 }}>
            {preview}
          </div>
        </div>

        {/* Controls */}
        <div style={{ display: "flex", alignItems: "center", gap: 5, flexShrink: 0, WebkitAppRegion: "no-drag" } as React.CSSProperties}>
          {/* Speed */}
          <button
            onClick={cycleSpeed}
            onMouseEnter={() => setHoveredBtn("speed")}
            onMouseLeave={() => setHoveredBtn(null)}
            style={{ ...btn("speed", 38), fontSize: 10, fontWeight: 700, color: "#6B7280", letterSpacing: "0.02em" }}
          >
            {speed === 1.0 ? "1" : speed}x
          </button>

          {/* Skip back 15s */}
          <button
            onClick={() => skipBack(15)}
            onMouseEnter={() => setHoveredBtn("back")}
            onMouseLeave={() => setHoveredBtn(null)}
            style={btn("back")}
            title="Back 15s"
          >
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M1 4v6h6" />
              <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10" />
            </svg>
          </button>

          {/* Play/Pause */}
          <button
            onClick={() => isPlaying ? pause() : isPaused ? resume() : play()}
            onMouseEnter={() => setHoveredBtn("play")}
            onMouseLeave={() => setHoveredBtn(null)}
            style={btn("play")}
          >
            {isLoading ? (
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" style={{ animation: "spin 1s linear infinite" }}>
                <circle cx="12" cy="12" r="10" strokeDasharray="20 44" strokeLinecap="round" />
              </svg>
            ) : isPlaying ? (
              <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor">
                <rect x="6" y="4" width="4" height="16" rx="1" />
                <rect x="14" y="4" width="4" height="16" rx="1" />
              </svg>
            ) : (
              <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor">
                <polygon points="6,3 20,12 6,21" />
              </svg>
            )}
          </button>

          {/* Skip forward 15s */}
          <button
            onClick={() => skipForward(15)}
            onMouseEnter={() => setHoveredBtn("fwd")}
            onMouseLeave={() => setHoveredBtn(null)}
            style={btn("fwd")}
            title="Forward 15s"
          >
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M23 4v6h-6" />
              <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
            </svg>
          </button>

          {/* Close */}
          <button
            onClick={() => { stop(); hide(); onClose(); }}
            onMouseEnter={() => setHoveredBtn("close")}
            onMouseLeave={() => setHoveredBtn(null)}
            style={btn("close")}
          >
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
              <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>
      </div>

      <style>{`
        @keyframes wave { 0%, 100% { transform: scaleY(0.5); } 50% { transform: scaleY(1); } }
        @keyframes spin { 100% { transform: rotate(360deg); } }
      `}</style>
    </div>
  );
}
