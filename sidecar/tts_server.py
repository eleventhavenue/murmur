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
    """Find the models directory — works for both dev and PyInstaller."""
    # PyInstaller sets _MEIPASS for bundled apps
    if hasattr(sys, '_MEIPASS'):
        return os.path.join(sys._MEIPASS, "models")
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

    def _clean_text(self, text: str) -> str:
        """Remove markdown, code symbols, mojibake, and non-speech characters."""
        import re

        # Fix common UTF-8 mojibake (CP1252 misinterpretation)
        # This is THE "a circumflex" bug — â€" â€™ â€œ etc
        mojibake_map = {
            'â€"': ', ',    # em dash
            'â€"': ', ',    # em dash variant
            'â€™': "'",     # right single quote
            'â€˜': "'",     # left single quote
            'â€œ': '"',     # left double quote
            'â€\x9d': '"',  # right double quote
            'â€¢': ', ',    # bullet
            'â€¦': '...',   # ellipsis
            'â†\x90': '',   # left arrow
            'â†\x92': ', ', # right arrow
            'Â': '',         # nbsp artifact
            '\u00e2': '',    # â character itself
            '\u0080': '',    # control char
            '\u0093': '',    # control char
            '\u0094': '',    # control char
            '\u0099': '',    # control char
        }
        for bad, good in mojibake_map.items():
            text = text.replace(bad, good)

        # Remove any remaining non-ASCII non-letter characters that kokoro might read
        # Keep letters, numbers, basic punctuation, and common accented chars
        text = re.sub(r'[^\w\s.,!?;:\'"()\-/&@%$€£]', ' ', text)

        # Remove markdown formatting
        text = re.sub(r'#{1,6}\s*', '', text)
        text = re.sub(r'\*{1,3}([^*]+)\*{1,3}', r'\1', text)
        text = re.sub(r'`{1,3}[^`]*`{1,3}', '', text)
        text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
        text = re.sub(r'!\[([^\]]*)\]\([^)]+\)', '', text)

        # Remove bullet points and list markers
        text = re.sub(r'^\s*[-*+]\s+', '', text, flags=re.MULTILINE)
        text = re.sub(r'^\s*\d+\.\s+', '', text, flags=re.MULTILINE)

        # Remove HTML tags
        text = re.sub(r'<[^>]+>', '', text)

        # Collapse multiple spaces/newlines
        text = re.sub(r'\n+', '. ', text)
        text = re.sub(r'\s{2,}', ' ', text)
        text = re.sub(r'[,.\s]{3,}', '. ', text)  # clean up repeated commas/dots
        return text.strip()

    def _split_sentences(self, text: str) -> list[str]:
        """Split text into sentences for more reliable synthesis."""
        import re
        # Split on sentence-ending punctuation followed by space or end
        parts = re.split(r'(?<=[.!?])\s+', text)
        # Merge very short fragments with the previous sentence
        merged = []
        for p in parts:
            p = p.strip()
            if not p:
                continue
            if merged and len(merged[-1]) < 30:
                merged[-1] += " " + p
            else:
                merged.append(p)
        return merged if merged else [text]

    def handle_synthesize(self, text: str, voice: str, speed: float):
        self._stop_requested = False
        try:
            # Clean surrogates and non-encodable chars from clipboard text
            text = text.encode("utf-8", errors="replace").decode("utf-8")
            text = text.strip()
            if not text:
                respond({"type": "error", "message": "No readable text"})
                return

            # Clean markdown, code symbols, and non-speech characters
            text = self._clean_text(text)
            if not text:
                respond({"type": "error", "message": "No readable text after cleaning"})
                return

            self._ensure_loaded()

            # Split into sentences for more reliable synthesis
            sentences = self._split_sentences(text)
            total_chunks = 0
            t0 = time.time()

            for sentence in sentences:
                if self._stop_requested:
                    respond({"type": "stopped"})
                    return

                samples, sr = self.kokoro.create(sentence, voice=voice, speed=speed)

                # Stream chunks of ~0.5 seconds for immediate playback
                chunk_size = sr // 2
                for i in range(0, len(samples), chunk_size):
                    if self._stop_requested:
                        respond({"type": "stopped"})
                        return
                    chunk = samples[i:i + chunk_size]
                    b64 = base64.b64encode(chunk.astype(np.float32).tobytes()).decode("ascii")
                    respond({"type": "chunk", "samples": b64, "sr": int(sr)})
                    total_chunks += 1

            dt = time.time() - t0
            sys.stderr.write(f"[murmur] Synthesized {len(sentences)} sentences in {dt:.1f}s\n")
            sys.stderr.flush()

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
