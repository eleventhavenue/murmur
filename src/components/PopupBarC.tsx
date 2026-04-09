import { useEffect, useState } from "react";
import { useTTS } from "../hooks/useTTS";

interface Props { text: string; onClose: () => void; }

export default function PopupBarC({ text, onClose }: Props) {
  const { state, error, speed, play, pause, resume, stop, hide, cycleSpeed } = useTTS(text, onClose);
  const [, setElapsed] = useState(0);
  const [hoveredBtn, setHoveredBtn] = useState<string | null>(null);

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
  const statusText = isLoading ? "Loading" : isPlaying ? "Reading" : isPaused ? "Paused" : isDone ? "Done" : "Ready";

  const solidBtn = (id: string): React.CSSProperties => ({
    width: 32, height: 32, background: hoveredBtn === id ? "#FAFAFA" : "#FFF",
    border: "1px solid rgba(0,0,0,0.04)", borderRadius: 6,
    boxShadow: "0 1px 2px rgba(0,0,0,0.05)", display: "flex",
    alignItems: "center", justifyContent: "center", color: "#1F2937",
    cursor: "pointer", transition: "all 0.15s ease",
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
          width: isLoading ? "10%" : isDone ? "100%" : isPlaying ? "50%" : "0%",
          transition: "width 0.3s ease",
        }} />
      </div>

      <div style={{ display: "flex", alignItems: "center", width: "100%", height: 65, padding: "0 12px", gap: 12 }}>
        {/* Drag handle */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", width: 24, height: 32, color: "#9CA3AF", flexShrink: 0 }}>
          <svg width="10" height="16" viewBox="0 0 10 16" fill="currentColor">
            <circle cx="2" cy="2" r="1.5" /><circle cx="8" cy="2" r="1.5" />
            <circle cx="2" cy="8" r="1.5" /><circle cx="8" cy="8" r="1.5" />
            <circle cx="2" cy="14" r="1.5" /><circle cx="8" cy="14" r="1.5" />
          </svg>
        </div>

        {/* Text */}
        <div style={{ flexGrow: 1, display: "flex", flexDirection: "column" as const, justifyContent: "center", minWidth: 0, gap: 2 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 11, fontWeight: 600, textTransform: "uppercase" as const, letterSpacing: "0.5px", color: "#6B7280" }}>
            {isPlaying && (
              <div style={{ display: "flex", alignItems: "flex-end", gap: 2, height: 10 }}>
                {[0, 0.2, 0.4].map((d, i) => (
                  <div key={i} style={{
                    width: 2, background: "currentColor", borderRadius: 1,
                    height: [4, 10, 6][i],
                    animation: "wave 1s ease-in-out infinite",
                    animationDelay: `${d}s`,
                  }} />
                ))}
              </div>
            )}
            {statusText}
          </div>
          <div style={{ fontSize: 14, fontWeight: 500, color: "#1F2937", whiteSpace: "nowrap" as const, overflow: "hidden", textOverflow: "ellipsis", lineHeight: 1.2 }}>
            {preview}
          </div>
        </div>

        {/* Controls */}
        <div style={{ display: "flex", alignItems: "center", gap: 8, flexShrink: 0 }}>
          {/* Speed */}
          <button
            onClick={cycleSpeed}
            onMouseEnter={() => setHoveredBtn("speed")}
            onMouseLeave={() => setHoveredBtn(null)}
            style={{ ...solidBtn("speed"), width: "auto", padding: "0 8px", fontSize: 11, fontWeight: 600, color: "#6B7280" } as React.CSSProperties}
          >
            {speed === 1.0 ? "1" : speed}x
          </button>

          {/* Play/Pause */}
          <button
            onClick={() => isPlaying ? pause() : isPaused ? resume() : play()}
            onMouseEnter={() => setHoveredBtn("play")}
            onMouseLeave={() => setHoveredBtn(null)}
            style={solidBtn("play") as React.CSSProperties}
          >
            {isLoading ? (
              <svg className="animate-spin" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <circle cx="12" cy="12" r="10" strokeDasharray="20 44" strokeLinecap="round" />
              </svg>
            ) : isPlaying ? (
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                <rect x="6" y="4" width="4" height="16" rx="1" />
                <rect x="14" y="4" width="4" height="16" rx="1" />
              </svg>
            ) : (
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                <polygon points="5,3 19,12 5,21" />
              </svg>
            )}
          </button>

          {/* Stop/Close */}
          <button
            onClick={() => { stop(); hide(); onClose(); }}
            onMouseEnter={() => setHoveredBtn("stop")}
            onMouseLeave={() => setHoveredBtn(null)}
            style={solidBtn("stop") as React.CSSProperties}
          >
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>
      </div>

      <style>{`@keyframes wave { 0%, 100% { transform: scaleY(0.5); } 50% { transform: scaleY(1); } }`}</style>
    </div>
  );
}
