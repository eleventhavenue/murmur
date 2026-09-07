# murmur.

**Your text, read beautifully.**

Highlight any text. Press a hotkey. Hear it read aloud, on your own machine.

[![Download](https://img.shields.io/github/v/release/eleventhavenue/murmur?label=Download&style=flat-square)](https://github.com/eleventhavenue/murmur/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue?style=flat-square)](LICENSE)
[![Website](https://img.shields.io/badge/website-murmurrrr.com-green?style=flat-square)](https://murmurrrr.com)

---

## What is Murmur?

Murmur is an open-source text-to-speech app that lives in your menu bar or system
tray. Highlight text anywhere, press a hotkey, and it reads it to you.

The free version runs entirely on your device. No account, no API keys, no
network. Cloud voices are an optional paid extra for people who want them.

| | Windows | macOS |
|---|---|---|
| Status | Stable, v0.2.0 | Beta, build from source |
| Hotkey | `Ctrl+Alt+M` | `⌘⇧M` |
| Local voices | 27, via kokoro-onnx | Apple system voices |
| Cloud voices | Planned | Murmur Cloud, Cartesia, Fish Audio |
| Bring your own model | Planned | Any OpenAI-compatible local server |
| Managed local engine | Bundled (383MB installer) | One-click Kokoro via Docker |
| Built with | Tauri, Rust, React | Swift, SwiftUI, AVFoundation |

The two apps are separate implementations that share a brand, a product and a
licensing backend. They do not share code, and they make different trade-offs:
the Windows build bundles a full neural TTS model for total offline
independence, the macOS build leans on the voices already in the operating
system and stays a few megabytes.

## Repository layout

```
murmur/
├── src/                # Windows: React popup UI (Vite)
├── src-tauri/          # Windows: Rust backend — tray, hotkey, audio, sidecar
├── sidecar/            # Windows: Python TTS engine (kokoro-onnx)
├── macos/              # macOS: native Swift app
├── site/               # Next.js website, auth, billing — murmurrrr.com
├── supabase/           # Database schema for the cloud tier
└── brand/              # Logos and brand guide
```

## Quick start

### Use it

Download from [Releases](https://github.com/eleventhavenue/murmur/releases/latest).
The Windows installer is large (around 383MB) because it bundles the offline TTS
model. There is no macOS installer yet, see below to build one.

### Build the macOS app

Needs only the Xcode **Command Line Tools**, not full Xcode.

```bash
cd macos
./build.sh run
```

That compiles with `swiftc`, assembles `build/Murmur.app`, signs it and launches
it. Grant Accessibility access when asked, then highlight text anywhere and press
`⌘⇧M`. See [macos/README.md](macos/README.md) for details.

### Build the Windows app

Needs Node 22+, Rust 1.94+ and Python 3.12+.

```bash
npm install
cd sidecar/models
curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin
cd ../..
npm run tauri dev
```

### Run the website

```bash
cd site
npm install
npm run dev
```

It builds and runs with **no environment variables at all**. Auth, billing and
licensing render as demo data until you connect them. Copy
[`site/.env.example`](site/.env.example) to `site/.env.local` when you are ready
to wire things up.

## The cloud tier

Everything above is free and always will be. Murmur Pro exists for people who
want premium neural voices without signing up for a TTS provider themselves.

The flow, end to end:

1. Sign in on murmurrrr.com with Google (Supabase Auth).
2. Subscribe through Stripe Checkout.
3. The Stripe webhook writes the subscription and activates a license key.
4. Paste that key into the desktop app.
5. The app calls `/api/tts`, which validates the key and proxies to the voice
   provider. The provider key stays on the server.

Bringing your own Cartesia or Fish Audio key is still supported, free, in the
app's settings. That path never touches our servers.

To set this up on your own infrastructure:

```bash
# 1. Apply the schema
supabase db push          # or paste supabase/migrations/0001_init.sql

# 2. Fill in site/.env.local  (see site/.env.example)

# 3. Forward webhooks while developing
stripe listen --forward-to localhost:3000/api/stripe/webhook
```

`MURMUR-DEMO-DEMO-DEMO-DEMO` always validates as Pro, so the desktop apps can be
developed against a real endpoint before any of this is connected.

## Voices

Windows ships 27 local voices via
[kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx) (82M parameters).

| Group | Voices |
|-------|--------|
| American Female | Alloy, Bella, Heart, Jessica, Nicole, Nova, River, Sarah, Sky |
| American Male | Adam, Echo, Eric, Liam, Michael |
| British Female | Alice, Emma, Lily |
| British Male | Daniel, Fable, George, Lewis |

macOS uses the voices already installed in the system. Higher-quality ones can be
downloaded in System Settings → Accessibility → Spoken Content.

## Roadmap

- [x] Global hotkey and selection capture
- [x] Local TTS with kokoro-onnx
- [x] Streaming audio playback
- [x] System tray with voice selector
- [x] Auto-updater via GitHub Releases
- [x] Website at murmurrrr.com
- [x] Sidecar bundling (PyInstaller) for zero-dependency install
- [x] macOS app
- [x] Subscription billing and license keys
- [x] Bring-your-own local TTS server (OpenAI-compatible)
- [x] One-click local engine setup, and server auto-discovery
- [x] Voice ranking that never picks a novelty voice
- [ ] Signed and notarized macOS installer
- [ ] Linux support
- [ ] Voice cloning

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security issues go to
[SECURITY.md](SECURITY.md), not the public issue tracker.

## License

[Apache 2.0](LICENSE). Free for personal and commercial use.

Bundled Instrument Serif is licensed under the
[SIL Open Font License](macos/Murmur/Resources/Fonts/OFL.txt).

## Links

- **Website:** [murmurrrr.com](https://murmurrrr.com)
- **Download:** [Latest release](https://github.com/eleventhavenue/murmur/releases/latest)
- **Issues:** [GitHub Issues](https://github.com/eleventhavenue/murmur/issues)

Built by [Nash Labs](https://nashlabs.ca).
