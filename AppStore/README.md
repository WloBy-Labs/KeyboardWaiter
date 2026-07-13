# App Store Route

This repository is now structured to target a sandboxed Mac App Store build:

- Global keyboard and pointer monitoring uses `CGEventTap` instead of `NSEvent` global monitors.
- The app requests explicit user consent before enabling monitoring.
- The app requests `Input Monitoring` through the public CoreGraphics APIs.
- Existing development data is migrated into the sandbox container on first launch when needed.

## What Still Requires Full Xcode

The current machine only has Command Line Tools, so it cannot produce an App Store archive here.
To finish App Store distribution, open the project on a Mac with full Xcode and:

1. Create a macOS App target for `KeyboardWaiter`.
2. Reuse `Resources/Info.plist` as the target Info.plist.
3. Set the target entitlements file to `AppStore/KeyboardWaiter.entitlements`.
4. Enable automatic signing with your Apple Developer team.
5. Use a bundle identifier you control for App Store distribution.
6. Archive, validate, and upload through Xcode Organizer or Transporter.

## Expected Runtime Behavior

- On first launch, the app shows an explicit consent alert before monitoring starts.
- After consent, the app requests `Input Monitoring`.
- If the app was previously running outside the sandbox, the SQLite database is copied into the sandbox container the first time the sandboxed build launches.

## Current Limitation

Without full Xcode in the current environment, the Xcode project and archive step cannot be validated here.
