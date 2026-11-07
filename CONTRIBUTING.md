# Contributing to Linefeed

Thanks for helping. Linefeed is small on purpose; these notes keep it that way.

## Getting started

1. Install Xcode 26 or later. Older SDKs build, but without Smart cleanup.
2. Run `./scripts/setup-signing-identity.sh` once so macOS keeps Linefeed's
   privacy permissions across rebuilds.
3. Run `./scripts/build-app.sh` to build, sign, and open the app.
4. Run the tests before every pull request:

   ```sh
   swift test -Xswiftc -strict-concurrency=complete
   ```

## Where things go

- A rule you can describe without AppKit, audio, or the file system belongs
  in `Sources/LinefeedCore`, with tests in `Tests/LinefeedCoreTests`.
- Everything else lives in `Sources/Linefeed`, in the folder for the feature
  it serves. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) has the map.
- Preferences belong in `Settings`. Views bind to it; don't add a second store.
- New messages about a recording belong in `RecordingReport`, so all of the
  copy stays in one place.
- A new shortcut behavior starts in `ShortcutEngine` and
  `RecordingCommand.resolve`, with a test that presses the keys the way a
  person would.

## Style

- Name things for what they mean to the person using Linefeed.
- Comment only what the code can't say: why a workaround exists, or how
  another app or macOS behaves.
- Write tests that would fail if the behavior broke, not tests that restate
  the implementation.
- Keep the build free of warnings with strict concurrency checking on.

## Brand

Colors and the mark are defined once in `Sources/LinefeedCore/Brand`. After
changing them, run `./scripts/render-brand-assets.sh` and commit the
regenerated icon, website icons, and color tokens.

## Privacy

Linefeed never sends audio, text, or screenshots anywhere. Its only network
use is the one-time download of each speech model. Changes that add other
network access or move data off the Mac won't be accepted.
