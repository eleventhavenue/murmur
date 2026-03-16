import { useEffect } from "react";
import { useTTS } from "../hooks/useTTS";

interface PopupBarProps {
  text: string;
  onClose: () => void;
}

function PopupBar({ text, onClose }: PopupBarProps) {
  const { state, error, speed, play, pause, resume, hide, cycleSpeed } =
    useTTS(text, onClose);

  // Auto-play when text arrives
  useEffect(() => {
    if (text && state.status === "idle" && state.progress === 0 && !error) {
      play("af_sky");
    }
  }, [text]); // eslint-disable-line react-hooks/exhaustive-deps

  const handlePlayPause = () => {
    if (state.status === "playing") {
      pause();
    } else if (state.status === "paused") {
      resume();
    } else if (state.status === "idle") {
      play("af_sky");
    }
  };

  const handleClose = async () => {
    await hide();
    onClose();
  };

  // Escape to close
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") handleClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const isDone = state.status === "idle" && state.progress === 100;

  const statusIcon = () => {
    if (state.status === "loading") {
      return (
        <svg className="w-5 h-5 animate-spin" viewBox="0 0 24 24" fill="none">
          <circle
            cx="12"
            cy="12"
            r="10"
            stroke="currentColor"
            strokeWidth="3"
            strokeDasharray="31.4 31.4"
          />
        </svg>
      );
    }
    if (state.status === "playing") {
      // Pause icon
      return (
        <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
          <rect x="6" y="4" width="4" height="16" rx="1" />
          <rect x="14" y="4" width="4" height="16" rx="1" />
        </svg>
      );
    }
    // Idle, paused, or done → play icon (replay)
    return (
      <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
        <polygon points="6,3 20,12 6,21" />
      </svg>
    );
  };

  const preview = error
    ? error.slice(0, 45)
    : text.length > 45
      ? text.slice(0, 45) + "..."
      : text;

  const subtitle = error
    ? "Error"
    : state.status === "loading"
      ? "Loading..."
      : isDone
        ? "Done — Sky"
        : "Sky";

  return (
    <div
      data-tauri-drag-region
      className="flex items-center gap-2 px-3 py-2.5 bg-[#161618]/95 rounded-full backdrop-blur-md border border-white/5 shadow-2xl select-none"
      style={{ WebkitAppRegion: "drag" } as React.CSSProperties}
    >
      {/* Play/Pause */}
      <button
        onClick={handlePlayPause}
        disabled={state.status === "loading"}
        className="flex items-center justify-center w-9 h-9 rounded-full bg-[#C8A87C] text-[#161618] hover:bg-[#D4B88C] transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed shrink-0"
        style={{ WebkitAppRegion: "no-drag" } as React.CSSProperties}
      >
        {statusIcon()}
      </button>

      {/* Text preview + status */}
      <div className="flex-1 min-w-0">
        <p
          className={`text-sm truncate leading-tight ${error ? "text-red-400" : "text-[#E8E8EC]"}`}
        >
          {preview}
        </p>
        <p
          className={`text-xs leading-tight ${error ? "text-red-400/60" : isDone ? "text-[#C8A87C]/70" : "text-[#8A8A94]"}`}
        >
          {subtitle}
        </p>
      </div>

      {/* Speed button */}
      <button
        onClick={cycleSpeed}
        className="px-2 py-1 text-xs font-medium text-[#8A8A94] hover:text-[#E8E8EC] hover:bg-white/5 rounded-md transition-colors cursor-pointer shrink-0 tabular-nums"
        style={{ WebkitAppRegion: "no-drag" } as React.CSSProperties}
        title="Cycle speed"
      >
        {speed}x
      </button>

      {/* Close */}
      <button
        onClick={handleClose}
        className="flex items-center justify-center w-7 h-7 rounded-full hover:bg-white/10 text-[#8A8A94] hover:text-[#E8E8EC] transition-colors cursor-pointer shrink-0"
        style={{ WebkitAppRegion: "no-drag" } as React.CSSProperties}
      >
        <svg
          className="w-4 h-4"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
        >
          <line x1="18" y1="6" x2="6" y2="18" />
          <line x1="6" y1="6" x2="18" y2="18" />
        </svg>
      </button>
    </div>
  );
}

export default PopupBar;
