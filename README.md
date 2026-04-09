# murmur.

**Your text, read beautifully.**

Highlight any text. Press `Ctrl+Alt+M`. Hear it read aloud — right on your device, no internet needed.

[![Download](https://img.shields.io/github/v/release/eleventhavenue/murmur?label=Download&style=flat-square)](https://github.com/eleventhavenue/murmur/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue?style=flat-square)](LICENSE)
[![Website](https://img.shields.io/badge/website-murmurrrr.com-green?style=flat-square)](https://murmurrrr.com)

---

## What is Murmur?

Murmur is an open-source text-to-speech desktop app. It lives in your system tray and reads any highlighted text aloud with a single hotkey. Everything runs locally — your text never leaves your machine.

**Key features:**
- **Global hotkey** — `Ctrl+Alt+M` from anywhere (browser, PDF, IDE, email)
- **100% offline** — no cloud, no API keys, no tracking
- **27 voices** — American & British, male & female
- **Speed control** — 0.75x to 3x playback
- **Tiny footprint** — 12MB installer, built with Tauri + Rust
- **3 UI designs** — switch between Brutalist, Industrial, and Clean styles
- **Auto-updates** — new versions delivered automatically

## Quick Start

1. **Download** the installer from [Releases](https://github.com/eleventhavenue/murmur/releases/latest)
2. Run the installer — Murmur appears in your system tray
3. **Highlight any text** in any application
4. Press **`Ctrl+Alt+M`**
5. Audio plays through your speakers

## Controls

| Action | How |
|--------|-----|
| Read text aloud | Highlight text → `Ctrl+Alt+M` |
| Pause / Resume | Click play/pause button on popup |
| Change speed | Click speed badge (cycles 0.75x → 3x) |
| Stop & close | Press `Escape` or click X |
| Change voice | Right-click tray → Voice |
| Change design | Right-click tray → Design |
| Quit | Right-click tray → Quit |

## Voices

27 voices across 4 groups:

| Group | Voices |
|-------|--------|
| American Female | Alloy, Bella, Heart, Jessica, Nicole, Nova, River, Sarah, Sky |
| American Male | Adam, Echo, Eric, Liam, Michael |
| British Female | Alice, Emma, Lily |
| British Male | Daniel, Fable, George, Lewis |

Powered by [kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx) (82M parameter model).

## Tech Stack

- **Frontend:** React + TypeScript + Tailwind CSS (Vite)
- **Backend:** Rust (Tauri v2)
- **TTS Engine:** kokoro-onnx (ONNX Runtime)
- **Audio:** rodio (pure Rust)
- **Distribution:** NSIS installer + GitHub Releases + auto-updater

## Development

### Prerequisites
- Node.js 22+
- Rust 1.94+
- Python 3.12+ with kokoro-onnx

### Setup
```bash
git clone https://github.com/eleventhavenue/murmur.git
cd murmur
npm install

# Download TTS model (~300MB)
cd sidecar/models
curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin
cd ../..

# Run in development
npm run tauri dev
```

### Build
```bash
npm run tauri build
```

Output: `src-tauri/target/release/bundle/nsis/Murmur_*_x64-setup.exe`

## Project Structure

```
murmur/
├── src/                    # React frontend (popup bar UI)
├── src-tauri/              # Rust backend (tray, hotkey, audio, sidecar)
├── sidecar/                # Python TTS engine (kokoro-onnx)
│   ├── tts_server.py       # stdin/stdout JSON protocol
│   └── models/             # ONNX model + voices (not in git)
├── site/                   # Next.js website (murmurrrr.com)
└── brand/                  # Logo concepts + brand guide
```

## Roadmap

- [x] Global hotkey + clipboard capture
- [x] Local TTS with kokoro-onnx
- [x] Streaming audio playback
- [x] System tray with voice selector
- [x] 3 UI design variants
- [x] Auto-updater via GitHub Releases
- [x] Website at murmurrrr.com
- [ ] Sidecar bundling (PyInstaller) for zero-dependency install
- [ ] macOS + Linux support
- [ ] Settings panel
- [ ] Cloud voices (Pro tier)
- [ ] Voice cloning

## License

[Apache 2.0](LICENSE) — free for personal and commercial use.

## Links

- **Website:** [murmurrrr.com](https://murmurrrr.com)
- **Download:** [Latest Release](https://github.com/eleventhavenue/murmur/releases/latest)
- **Issues:** [GitHub Issues](https://github.com/eleventhavenue/murmur/issues)

Built by [Nash Labs](https://nashlabs.ca).
