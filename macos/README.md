# Murmur

The opposite of Wispr Flow. Highlight any text, press **⌘⇧M**, and Murmur reads it to you in a small floating player at the top of your screen.

## Run it

```bash
./build.sh run
```

Compiles with `swiftc`, assembles `build/Murmur.app`, signs it and launches. Needs only the Xcode **Command Line Tools** — no full Xcode install, no `xcodegen`.

`Murmur.xcodeproj` is still there if you install Xcode and prefer to work in it; regenerate it with `xcodegen generate` after changing `project.yml`.

### Signing, and why the Accessibility permission keeps resetting

macOS ties the Accessibility grant to the app's code signature. An ad-hoc build gets a new signature every time it is rebuilt, so the grant silently stops applying — and System Settings still shows the toggle as enabled, which makes it look like a bug in Murmur rather than a stale permission.

Any stable certificate fixes it, and you need neither Xcode nor an Apple ID:

1. Open **Keychain Access** → menu **Certificate Assistant** → **Create a Certificate…**
2. Name it `Murmur Dev`, Identity Type **Self Signed Root**, Certificate Type **Code Signing**
3. Create it, then run `./build.sh` again

`build.sh` finds it automatically and the permission then survives rebuilds. It prefers an Apple Development certificate when you have one, and `MURMUR_SIGN_IDENTITY` overrides both.

If the permission is already stuck, clear the stale entry and grant it fresh:

```bash
tccutil reset Accessibility ai.murmur.app
```

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
| Local Server | anything you host | a URL |
| Murmur Cloud | Sonic-3, streamed | a Murmur Pro licence key |
| Cartesia | Sonic-3, streamed | API key from play.cartesia.ai |
| Fish Audio | S1 | API key from fish.audio |

**Local Server** runs a real neural engine on your own machine. Choose it and
press **Download and start**: Murmur pulls Kokoro via Docker, runs it, and points
itself at it. After that the engine wakes on demand, so a reboot costs you
nothing. Nothing you read ever leaves your computer.

Murmur orchestrates rather than bundles. The image comes from upstream through
your own Docker, so no model weights ship with the app and none of their licences
come with it either — Kokoro's grapheme-to-phoneme stack depends on espeak-ng and
phonemizer, both GPL-3.0.

Already running something? Press **Scan** and Murmur finds it. Anything speaking
OpenAI's `/v1/audio/speech` works: Kokoro-FastAPI, LM Studio, LocalAI, Speaches.
It probes the usual ports, reads the server's model and voice lists, and fills
the fields in for you. Murmur asks for `pcm` so
playback starts on the first bytes, and reads a WAV header instead if the server
sends one. Most servers need no key; the field is there for proxies that do.

Changing the voice plays a short sample, the way System Settings auditions
system voices. That applies to System and Local Server. It is deliberately not
automatic for Cartesia, Fish or Murmur Cloud, where every preview is a billable
request; those have a play button instead.

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

## Voices on macOS

A stock Mac ships only "compact" voices, which is why system speech sounds
robotic. Apple's Enhanced and Premium voices are a free download and are far
better; almost nobody knows they exist. Murmur detects when none are installed
and offers a button straight to the download pane.

Voice selection is ranked by lineage rather than the system quality flag, because
that flag reports `.default` for all 41 English voices on a stock Mac. Sorting on
it leaves everything tied, which made the "best available" choice arbitrary and
occasionally a novelty voice — Murmur could legitimately have picked Bubbles or
Zarvox. Ranking on the identifier prefix instead
(`com.apple.voice.premium` > `enhanced` > `compact` > `com.apple.eloquence` >
`com.apple.speech.synthesis.voice`) makes it deterministic, and ties break toward
your own regional variant.

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
  Speech/     SpeechProvider protocol, Local Server, Murmur Cloud, Cartesia, Fish, System voice, streaming HTTP
  Audio/      AVAudioEngine pipeline with time-pitch and level tap
  Reader/     ReaderSession orchestration, per-chunk audio cache
  UI/         Theme, Waveform, ReaderView/Panel, Settings, hotkey recorder
```
