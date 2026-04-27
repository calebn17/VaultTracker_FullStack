# VaultTracker iOS App

**Layers, directory layout, endpoints, offline Home stack, household/FIRE behavior, tests, and verification:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Commands

**SwiftLint** (from `VaultTrackerIOS/VaultTracker/`; install: `brew install swiftlint`):

```bash
swiftlint lint
swiftlint --fix
```

**Unit tests** (run from repository root; pick a simulator that exists on your machine):

```bash
cd VaultTrackerIOS && xcodebuild test -project VaultTracker.xcodeproj -scheme VaultTracker -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:VaultTrackerTests
```

In Xcode: scheme **VaultTracker**, **Cmd+U**. Full CI destinations: root [`CLAUDE.md`](../../CLAUDE.md).

## Rules

- **Identifiers:** Do not change `accessibilityIdentifier` values without updating `VaultTrackerUITests/PageObjects/`.
- **Secrets:** Never commit `GoogleService-Info.plist` or real Firebase keys; use the example template and CI path as in `Documentation/system_design.md`.
- **Subfolders:** Feature and area-specific notes may live in each directory’s `CLAUDE.md`.
