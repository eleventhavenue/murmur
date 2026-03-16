import { useState, useEffect, useCallback } from "react";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";
import type { TTSState } from "../lib/types";

const SPEED_OPTIONS = [0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0];

export function useTTS(text: string, onFinished?: () => void) {
  const [state, setState] = useState<TTSState>({
    status: "idle",
    text,
    voice: null,
    progress: 0,
  });
  const [error, setError] = useState<string | null>(null);
  const [speed, setSpeedState] = useState(1.0);

  useEffect(() => {
    const unlistenChunk = listen<{ samples: string; sr: number }>(
      "audio-chunk",
      async (event) => {
        const { samples, sr } = event.payload;
        try {
          await invoke("audio_play_chunk", {
            samplesB64: samples,
            sampleRate: sr,
          });
          setState((s) =>
            s.status === "loading" ? { ...s, status: "playing" } : s,
          );
        } catch (e) {
          console.error("Audio chunk error:", e);
        }
      },
    );

    const unlistenDone = listen("synthesis-done", async () => {
      // All chunks sent to rodio — tell audio thread to watch for empty sink
      await invoke("audio_mark_done");
    });

    const unlistenFinished = listen("playback-finished", () => {
      // Rodio sink is empty — playback truly done
      setState((s) => ({ ...s, status: "idle", progress: 100 }));
    });

    const unlistenStopped = listen("playback-stopped", () => {
      setState((s) => ({ ...s, status: "idle", progress: 0 }));
    });

    const unlistenSynthStopped = listen("synthesis-stopped", () => {
      // Sidecar acknowledged stop
    });

    const unlistenError = listen<{ message: string }>(
      "sidecar-error",
      (event) => {
        setError(event.payload.message);
        setState((s) => ({ ...s, status: "idle" }));
      },
    );

    return () => {
      unlistenChunk.then((fn) => fn());
      unlistenDone.then((fn) => fn());
      unlistenFinished.then((fn) => fn());
      unlistenStopped.then((fn) => fn());
      unlistenSynthStopped.then((fn) => fn());
      unlistenError.then((fn) => fn());
    };
  }, [onFinished]);

  const play = useCallback(
    async (voice: string = "af_sky") => {
      setError(null);
      setState((s) => ({ ...s, status: "loading", progress: 0 }));
      try {
        await invoke("synthesize", { text, voice, speed });
      } catch (e) {
        console.error("Synthesis error:", e);
        setError(String(e));
        setState((s) => ({ ...s, status: "idle" }));
      }
    },
    [text, speed],
  );

  const pause = useCallback(async () => {
    await invoke("audio_pause");
    setState((s) => ({ ...s, status: "paused" }));
  }, []);

  const resume = useCallback(async () => {
    await invoke("audio_resume");
    setState((s) => ({ ...s, status: "playing" }));
  }, []);

  const stop = useCallback(async () => {
    await invoke("audio_stop");
    await invoke("stop_synthesis").catch(() => {});
    setState((s) => ({ ...s, status: "idle", progress: 0 }));
  }, []);

  const hide = useCallback(async () => {
    await stop();
    const win = getCurrentWindow();
    await win.hide();
  }, [stop]);

  const setSpeed = useCallback(async (newSpeed: number) => {
    setSpeedState(newSpeed);
    await invoke("audio_set_speed", { speed: newSpeed });
  }, []);

  const cycleSpeed = useCallback(async () => {
    const idx = SPEED_OPTIONS.indexOf(speed);
    const next = SPEED_OPTIONS[(idx + 1) % SPEED_OPTIONS.length];
    await setSpeed(next);
  }, [speed, setSpeed]);

  return { state, error, speed, play, pause, resume, stop, hide, setSpeed, cycleSpeed };
}
