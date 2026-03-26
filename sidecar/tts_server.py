"""
Murmur TTS Sidecar — stdin/stdout JSON protocol.

Reads JSON commands from stdin (one per line), writes JSON responses to stdout.
Uses kokoro-onnx for local TTS synthesis.
"""

import sys
import json
import base64
import os
import time
import numpy as np

# Voice metadata (matches kokoro-onnx v1.0 voice IDs)
VOICES = {
    "American Female": [
        ("af_alloy", "Alloy"), ("af_aoede", "Aoede"), ("af_bella", "Bella"),
        ("af_heart", "Heart"), ("af_jessica", "Jessica"), ("af_kore", "Kore"),
        ("af_nicole", "Nicole"), ("af_nova", "Nova"), ("af_river", "River"),
        ("af_sarah", "Sarah"), ("af_sky", "Sky"),
    ],
    "American Male": [
        ("am_adam", "Adam"), ("am_echo", "Echo"), ("am_eric", "Eric"),
        ("am_fenrir", "Fenrir"), ("am_liam", "Liam"), ("am_michael", "Michael"),
        ("am_onyx", "Onyx"), ("am_puck", "Puck"),
    ],
    "British Female": [
        ("bf_alice", "Alice"), ("bf_emma", "Emma"),
        ("bf_isabella", "Isabella"), ("bf_lily", "Lily"),
    ],
    "British Male": [
        ("bm_daniel", "Daniel"), ("bm_fable", "Fable"),
        ("bm_george", "George"), ("bm_lewis", "Lewis"),
    ],
}


def get_model_dir():
    """Find the models directory relative to this script."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")


def respond(data: dict):
    """Write a JSON line to stdout."""
    sys.stdout.write(json.dumps(data) + "\n")
    sys.stdout.flush()


class TTSServer:
    def __init__(self):
        self.kokoro = None
        self._stop_requested = False

    def _ensure_loaded(self):
        if self.kokoro is not None:
            return
        from kokoro_onnx import Kokoro
        model_dir = get_model_dir()
        model_path = os.path.join(model_dir, "kokoro-v1.0.onnx")
        voices_path = os.path.join(model_dir, "voices-v1.0.bin")
        t0 = time.time()
        self.kokoro = Kokoro(model_path, voices_path)
        dt = time.time() - t0
        sys.stderr.write(f"[murmur] Model loaded in {dt:.1f}s\n")
        sys.stderr.flush()

    def handle_list_voices(self):
        voices = []
        for group, group_voices in VOICES.items():
            for vid, vname in group_voices:
                voices.append({"id": vid, "name": vname, "group": group})
        respond({"type": "voices", "voices": voices})

    def handle_synthesize(self, text: str, voice: str, speed: float):
        self._stop_requested = False
        try:
            # Clean surrogates and non-encodable chars from clipboard text
            text = text.encode("utf-8", errors="replace").decode("utf-8")
            text = text.strip()
            if not text:
                respond({"type": "error", "message": "No readable text"})
                return

            self._ensure_loaded()

            t0 = time.time()
            samples, sr = self.kokoro.create(text, voice=voice, speed=speed)
            dt = time.time() - t0
            sys.stderr.write(f"[murmur] Synthesized {len(samples)/sr:.1f}s audio in {dt:.1f}s\n")
            sys.stderr.flush()

            # Stream chunks of ~0.5 seconds for immediate playback
            chunk_size = sr // 2
            total_chunks = 0

            for i in range(0, len(samples), chunk_size):
                if self._stop_requested:
                    respond({"type": "stopped"})
                    return
                chunk = samples[i:i + chunk_size]
                b64 = base64.b64encode(chunk.astype(np.float32).tobytes()).decode("ascii")
                respond({"type": "chunk", "samples": b64, "sr": int(sr)})
                total_chunks += 1

            respond({"type": "done", "total_chunks": total_chunks})
        except Exception as e:
            respond({"type": "error", "message": str(e)})

    def handle_stop(self):
        self._stop_requested = True
        respond({"type": "stopped"})

    def run(self):
        """Main loop: read JSON commands from stdin."""
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                cmd = json.loads(line)
            except json.JSONDecodeError as e:
                respond({"type": "error", "message": f"Invalid JSON: {e}"})
                continue

            action = cmd.get("cmd")
            if action == "list_voices":
                self.handle_list_voices()
            elif action == "synthesize":
                self.handle_synthesize(
                    text=cmd.get("text", ""),
                    voice=cmd.get("voice", "af_sky"),
                    speed=cmd.get("speed", 1.0),
                )
            elif action == "stop":
                self.handle_stop()
            else:
                respond({"type": "error", "message": f"Unknown command: {action}"})


if __name__ == "__main__":
    server = TTSServer()
    server.run()
