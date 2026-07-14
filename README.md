# KeyboardWaiter

Native macOS menu bar app that counts keyboard presses plus mouse/trackpad activity, stores hourly aggregates in SQLite, and shows daily totals plus a 24-hour trend.

## Downloads and Installation

Prebuilt DMGs are published on the [Releases page](https://github.com/WloBy-Labs/KeyboardWaiter/releases).

1. Download `KeyboardWaiter-<version>.dmg` and open it.
2. Drag `KeyboardWaiter.app` onto the `Applications` folder.
3. Launch it from Applications.

Because releases are currently **not notarized by Apple**, macOS Gatekeeper will
warn the first time you open the app ("cannot be opened because the developer
cannot be verified"). To open it:

- Right-click (or Control-click) the app in Applications and choose **Open**, then
  confirm **Open** in the dialog. You only need to do this once per version.
- If the app appears "damaged", clear the quarantine flag once:
  ```bash
  xattr -dr com.apple.quarantine /Applications/KeyboardWaiter.app
  ```

On first run the app asks for monitoring consent, then requests **Input
Monitoring** in System Settings. Grant it under
`System Settings → Privacy & Security → Input Monitoring`.

> Note: unsigned/ad-hoc builds change their code signature on every release, so
> macOS may ask you to re-grant Input Monitoring after each update. This goes
> away with a stable Developer ID (see "Releasing via GitHub Actions" below).

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

## Releasing via GitHub Actions

Releasing is one step: push a version tag. `.github/workflows/release.yml`
builds the `.app`, wraps it in a DMG, and publishes it to GitHub Releases.

```bash
git tag v0.8.0
git push origin v0.8.0
```

That's all that's required — no accounts, no secrets, no local build. The
workflow builds the tagged version, attaches the DMG to the release, and uses
`release_notes/v<version>.md` as the release body when that file exists
(otherwise it auto-generates notes). You can also trigger it manually from the
Actions tab (`workflow_dispatch`) to produce a DMG artifact without publishing.

### Optional: keep Input Monitoring across updates

The default DMG is ad-hoc signed, so macOS may ask users to re-grant Input
Monitoring after each update. To avoid that, generate one stable self-signed
certificate (no Apple account needed) and store it as repository secrets:

```bash
zsh scripts/make_signing_cert.sh   # prints MACOS_CERT_P12 and MACOS_CERT_PASSWORD
```

Add the two printed values under **Settings → Secrets and variables → Actions**,
then keep the generated `dist/signing-cert.p12` and its password backed up so
every release reuses the same identity. The workflow signs with it automatically
when the secrets are present. (This does not remove the first-launch Gatekeeper
warning; only a paid Developer ID with notarization does.)

### Optional: remove the Gatekeeper warning (Developer ID)

With an Apple Developer account, add `APPLE_ID`, `APPLE_TEAM_ID`, and
`APPLE_APP_PASSWORD` secrets alongside a Developer ID certificate in
`MACOS_CERT_P12`. The workflow then notarizes and staples the app, and it
installs with no warning. When the certificate name contains "Developer ID", the
hardened runtime and a secure timestamp are enabled automatically.

## Stored Data

Aggregated counts are written to:

`~/Library/Application Support/KeyboardWaiter/keyboard_waiter.sqlite3`

Only aggregated hourly counts are stored. Raw keystroke contents are not persisted.
Exported JSON snapshots contain the same hourly aggregate counts, not raw typed content.
