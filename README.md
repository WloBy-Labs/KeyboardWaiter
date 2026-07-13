# KeyboardWaiter

Native macOS menu bar app that counts keyboard presses plus mouse/trackpad activity, stores hourly aggregates in SQLite, and shows daily totals plus a 24-hour trend.

## Requirements

- macOS 13+
- Swift 5.8+
- Input Monitoring permission granted in System Settings

## Build and Run

```bash
./scripts/build_binary.sh
./.build/manual/KeyboardWaiter
```

This path works with the macOS Command Line Tools that are available in the current environment.
If you later install full Xcode, you can also try `swift build` / `swift test`.

The app runs as a menu bar utility. The menu bar title shows today's keyboard total.
Use the menu item `Open Input View` to open a visual window with a keyboard heatmap, mouse/trackpad counters, and a year/month/day calendar grid.
The menu also shows the packaged app version and build timestamp so you can confirm which build is running.
The menu includes a `Language` switch. English is the default; Chinese can be enabled at runtime.
The app now asks for explicit monitoring consent before enabling global input counting.
Use `Export Statistics...` and `Import Statistics...` to move aggregated hourly counts between machines. Import supports merge and replace modes.

## App Store Direction

The codebase is now being aligned with a sandboxed Mac App Store build:

- keyboard plus pointer monitoring both use `CGEventTap`
- monitoring starts only after explicit in-app consent
- the app requests `Input Monitoring` through `CGRequestListenEventAccess()`
- legacy development data is copied into the sandbox container on first launch when needed

See `AppStore/README.md` for the remaining Xcode-specific archive and signing steps.

## Stable Signing for macOS Permissions

To keep Input Monitoring permission across rebuilds, create a stable local signing identity once:

```bash
zsh scripts/bootstrap_local_signing.sh
zsh scripts/package_app.sh
```

This creates or reuses a stable local code-signing identity and writes its exact certificate fingerprint to `~/Library/Application Support/KeyboardWaiter/signing/signing.env`.
`package_app.sh` signs with that fingerprint, so duplicate cert names in other keychains do not break packaging.
After switching from ad-hoc signing to the stable identity, macOS will usually require one final Input Monitoring grant.
Subsequent rebuilds from the same bundle ID and signing fingerprint should keep the same privacy identity.

## Package as `.app`

```bash
./scripts/package_app.sh
open dist/KeyboardWaiter.app
```

The generated app is a development build. On first launch, macOS may require manual approval and Input Monitoring access.
If a previous unsigned or ad-hoc build left behind a stale `KeyboardWaiter` entry, remove that stale entry once and then enable the newly signed app.

## Stored Data

Aggregated counts are written to:

`~/Library/Application Support/KeyboardWaiter/keyboard_waiter.sqlite3`

Only aggregated hourly counts are stored. Raw keystroke contents are not persisted.
Exported JSON snapshots contain the same hourly aggregate counts, not raw typed content.
