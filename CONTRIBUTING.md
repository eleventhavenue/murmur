# Contributing to Murmur

Thanks for looking. Murmur is a small project, so the process is light.

## Ways in

The fastest useful contributions are usually:

- **Bug reports** with the exact steps and, on macOS, the tail of
  `~/Library/Logs/Murmur.log`.
- **Text cleanup rules.** Murmur strips markdown, ANSI codes, box drawing and
  terminal prompts before speaking. Real examples of text that reads badly are
  genuinely valuable.
- **Voices and languages** beyond English.
- **Linux support**, which nobody has started.

## Getting set up

Each part of the repo stands alone. You do not need to build all of it.

| Working on | Needs | Start with |
|---|---|---|
| macOS app | Xcode Command Line Tools | `cd macos && ./build.sh run` |
| Windows app | Node 22+, Rust 1.94+, Python 3.12+ | `npm install && npm run tauri dev` |
| Website | Node 22+ | `cd site && npm install && npm run dev` |

The website builds and runs with no environment variables. Auth, billing and
licensing show demo data until you connect keys, so you can work on layout,
copy and components without a Supabase or Stripe account.

## Conventions

- Match the surrounding code. Neither app has a house style beyond that.
- Comments should explain *why*, not restate the code. If a workaround exists
  because a platform API misbehaves, say which one and how.
- Keep commits focused. One concern per pull request.
- The desktop apps must keep working fully offline. Any network call belongs
  behind an explicit user choice, never on a default path.

## Before opening a pull request

```bash
cd macos && ./build.sh        # macOS app compiles
cd site && npx tsc --noEmit && npm run build   # site type-checks and builds
```

## Privacy is a feature, not a default

Murmur reads whatever the user highlighted, which is often private. Text must
not be logged, cached to disk, or sent anywhere the user did not explicitly opt
into. Changes that weaken this will be turned down even if they are convenient.

## License

Contributions are accepted under the [Apache 2.0](LICENSE) license.
