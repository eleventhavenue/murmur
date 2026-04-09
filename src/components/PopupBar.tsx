import { useEffect, useState } from "react";
import { useTTS } from "../hooks/useTTS";

interface PopupBarProps {
  text: string;
  onClose: () => void;
}

function PopupBar({ text, onClose }: PopupBarProps) {
  const { state, error, speed, play, pause, resume, hide, cycleSpeed } =
    useTTS(text, onClose);
  const [elapsed, setElapsed] = useState(0);

  // Auto-play when new text arrives
  useEffect(() => {
    if (text && !error) {
      play("af_sky");
      setElapsed(0);
    }
  }, [text]); // eslint-disable-line react-hooks/exhaustive-deps

  // Timer
  useEffect(() => {
    if (state.status !== "playing") return;
    const interval = setInterval(() => setElapsed((t) => t + 1), 1000);
    return () => clearInterval(interval);
  }, [state.status]);

  const handlePlayPause = () => {
    if (state.status === "playing") pause();
    else if (state.status === "paused") resume();
    else if (state.status === "idle") {
      setElapsed(0);
      play("af_sky");
    }
  };

  const handleClose = async () => {
    await hide();
    onClose();
  };

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") handleClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const isDone = state.status === "idle" && state.progress === 100;

  const formatTime = (s: number) =>
    `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

  const preview = error
    ? error.slice(0, 50)
    : text.length > 50
      ? text.slice(0, 50) + "\u2026"
      : text;

  return (
    <div
      data-tauri-drag-region
      className="flex items-center gap-3 w-full h-full px-4 bg-[#131315]/95 rounded-[20px] backdrop-blur-xl border border-white/[0.06] shadow-[0_8px_32px_rgba(0,0,0,0.4)] select-none"
      style={{ WebkitAppRegion: "drag" } as React.CSSProperties}
    >
      {/* Play/Pause button */}
      <button
        onClick={handlePlayPause}
        disabled={state.status === "loading"}
        className="flex items-center justify-center w-10 h-10 rounded-full shrink-0 transition-all duration-200 cursor-pointer disabled:cursor-wait"
        style={{
          background:
            state.status === "loading"
              ? "rgba(200,168,124,0.3)"
              : "#C8A87C",
          color: "#131315",
          WebkitAppRegion: "no-drag",
        } as React.CSSProperties}
      >
        {state.status === "loading" ? (
          <svg className="w-5 h-5 animate-spin" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="10" stroke="#C8A87C" strokeWidth="2.5" strokeDasharray="20 44" strokeLinecap="round" />
          </svg>
        ) : state.status === "playing" ? (
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
            <rect x="6" y="4" width="4" height="16" rx="1.5" />
            <rect x="14" y="4" width="4" height="16" rx="1.5" />
          </svg>
        ) : (
          <svg className="w-4 h-4 ml-0.5" viewBox="0 0 24 24" fill="currentColor">
            <polygon points="7,3 21,12 7,21" />
          </svg>
        )}
      </button>

      {/* Center — text + status */}
      <div className="flex-1 min-w-0 flex flex-col justify-center">
        <p className={`text-[13px] font-medium truncate leading-snug ${error ? "text-red-400" : "text-white/90"}`}>
          {preview}
        </p>
        <div className="flex items-center gap-2 mt-0.5">
          {state.status === "playing" && (
            <span className="flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-[#C8A87C] animate-pulse" />
              <span className="text-[10px] text-[#C8A87C]/70 font-medium">Playing</span>
            </span>
          )}
          {state.status === "paused" && (
            <span className="text-[10px] text-white/30 font-medium">Paused</span>
          )}
          {state.status === "loading" && (
            <span className="text-[10px] text-white/30 font-medium">Synthesizing...</span>
          )}
          {isDone && (
            <span className="text-[10px] text-[#C8A87C]/50 font-medium">Done</span>
          )}
          {error && (
            <span className="text-[10px] text-red-400/60 font-medium">Error</span>
          )}
          {(state.status === "playing" || state.status === "paused") && (
            <span className="text-[10px] text-white/20 font-mono tabular-nums">
              {formatTime(elapsed)}
            </span>
          )}
        </div>
      </div>

      {/* Speed */}
      <button
        onClick={cycleSpeed}
        className="px-2.5 py-1 text-[11px] font-semibold text-white/30 hover:text-white/60 hover:bg-white/[0.04] rounded-md transition-all cursor-pointer shrink-0 tabular-nums"
        style={{ WebkitAppRegion: "no-drag" } as React.CSSProperties}
      >
        {speed === 1.0 ? "1" : speed}x
      </button>

      {/* Divider */}
      <div className="w-px h-5 bg-white/[0.06] shrink-0" />

      {/* Close */}
      <button
        onClick={handleClose}
        className="flex items-center justify-center w-7 h-7 rounded-full hover:bg-white/[0.06] text-white/25 hover:text-white/50 transition-all cursor-pointer shrink-0"
        style={{ WebkitAppRegion: "no-drag" } as React.CSSProperties}
      >
        <svg className="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
          <line x1="18" y1="6" x2="6" y2="18" />
          <line x1="6" y1="6" x2="18" y2="18" />
        </svg>
      </button>
    </div>
  );
}

export default PopupBar;
