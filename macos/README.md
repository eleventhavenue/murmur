# Murmur

The opposite of Wispr Flow. Highlight any text, press **⌘⇧M**, and Murmur reads it to you in a small floating player at the top of your screen.

## Run it

```bash
./build.sh run
```

Compiles with `swiftc`, assembles `build/Murmur.app`, signs it and launches. Needs only the Xcode **Command Line Tools** — no full Xcode install, no `xcodegen`.

`Murmur.xcodeproj` is still there if you install Xcode and prefer to work in it; regenerate it with `xcodegen generate` after changing `project.yml`.

Without an Apple Development signing identity the app is ad-hoc signed, and macOS drops the Accessibility grant on every rebuild. Adding a free Apple ID signing certificate in Xcode fixes that permanently.

First launch opens the setup window and asks for **Accessibility** access. That's what lets Murmur see what you've highlighted.

## How it works

- **Select + ⌘⇧M** reads the selection. Selection is read through the Accessibility API first, then a silent ⌘C with your clipboard restored (Chrome, VS Code, Electron apps).
- **Press again** while it's playing to pause and resume. Select something new and press to switch.
- **Nothing selected?** Murmur enters **Lens** mode: point at any block of text on screen, click, and it reads that block. Esc cancels.
- **Speed chips** (0.8× to 2×) change the playback rate live without changing pitch. Arrow keys ↑↓ do the same once you click the panel; ←→ skip sentences, space pauses, esc closes.
- The **teleprompter** highlights the sentence being spoken. The text icon expands the full script and lets you click any sentence to jump to it.
- Text is **cleaned before it's spoken**: markdown, code fences, HTML tags, ANSI colour codes, box-drawing characters, bullets and terminal prompts are stripped, URLs read as their domain, and hard-wrapped lines are re-flowed into sentences.

## Voices

| Provider | Model | Needs |
| --- | --- | --- |
| System | Apple voices, on-device | nothing |
| Murmur Cloud | Sonic-3, streamed | a Murmur Pro licence key |
| Cartesia | Sonic-3, streamed | API key from play.cartesia.ai |
| Fish Audio | S1 | API key from fish.audio |

**Murmur Cloud** is the paid tier: premium voices without signing up for a TTS
provider yourself. Paste the licence key from
[murmurrrr.com/account](https://murmurrrr.com/account) into Settings and press
Check. Bringing your own Cartesia or Fish key stays free and never touches our
servers.

Keys live in the macOS Keychain. All three flow through the same audio pipeline (player → time-pitch → mixer), so speed control and the waveform behave identically.

## Claude Code

Hear every reply as it lands. Add this to `~/.claude/settings.json` (the Settings window has a copy button with the right path filled in):

```json
"hooks": {
  "Stop": [{ "hooks": [{ "type": "command", "command": "\"/path/to/Murmur.app/Contents/MacOS/Murmur\" --hook" }] }]
}
```

## CLI

```bash
build/Murmur.app/Contents/MacOS/Murmur read "Hello there"
echo "piped text" | build/Murmur.app/Contents/MacOS/Murmur read -
open "murmur://read?text=Hello%20there"
```

Logs: `~/Library/Logs/Murmur.log`.

To point the app at a local website while developing the cloud tier:

```bash
defaults write ai.murmur.app apiBase http://localhost:3000
```

## Design

The app uses the same brand as [murmurrrr.com](https://murmurrrr.com): bone
background, deep green ink, one yellow accent, and Instrument Serif for display
type. The tokens live in `Sources/UI/Theme.swift` and mirror
`site/src/app/globals.css`; change one and change the other. Instrument Serif is
bundled in `Resources/Fonts` under the SIL Open Font License. UI text uses the
system face, which is better tuned for macOS than a bundled sans would be.

## Layout

```
Murmur/Sources
  App/        main, AppDelegate (menu bar, hotkey routing, URL scheme), CLI
  Hotkey/     Carbon global hotkey
  Capture/    Accessibility helpers, selection capture, Lens overlay
  Text/       TextCleaner, Chunker (sentence-sized chunks via NLTokenizer)
  Speech/     SpeechProvider protocol, Murmur Cloud, Cartesia, Fish, System voice, streaming HTTP
  Audio/      AVAudioEngine pipeline with time-pitch and level tap
  Reader/     ReaderSession orchestration, per-chunk audio cache
  UI/         Theme, Waveform, ReaderView/Panel, Settings, hotkey recorder
```
