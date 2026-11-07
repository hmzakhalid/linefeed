# Linefeed architecture

Linefeed is a native macOS menu-bar app. Rules that can be tested without a
Mac's hardware live in `LinefeedCore`; the app target wires those rules to
AppKit, SwiftUI, audio, and the system.

## A recording, end to end

1. **Shortcuts.** `InputMonitor` feeds key and modifier events to
   `ShortcutEngine`, which turns them into gestures: a hold began or ended, a
   shortcut was toggled, or Escape was pressed. Keys in a shortcut are
   registered as system hot keys so they never reach other apps.
2. **One decision.** `RecordingCommand.resolve(gesture, in: phase)` is the
   only place a gesture meets the recording state. Every pairing is spelled
   out, so starting, stopping, promoting a quick note to hands-free, and
   discarding can't disagree with each other.
3. **Recording.** `RecordingController` starts the microphone
   (`AudioRecorder`), samples the pointer (`PointerTracker`), draws the trail
   (`TrailOverlayController`), and shows the island
   (`RecordingIslandController`). A recognized circle
   (`CircleGestureDetector`) becomes a screenshot in the session's folder,
   stamped with its offset on the audio clock. If macOS changes the audio
   route mid-recording, the session finishes with what was heard.
4. **Text.** `SpeechEngine` transcribes locally with FluidAudio and returns
   timed words. `TextPolisher` applies the writing style, the person's
   vocabulary, and technical terms; `SmartCleanup` optionally asks Apple
   Intelligence for a grammar pass and keeps it only if it stays faithful.
5. **Outcome.** `RecordingOutcome` decides whether anything was captured.
   The session is delivered first and then saved: `SessionStore` writes
   `session.json` and `context.md`, linking each screenshot to the words
   spoken around it (`ContextTimeline`). A shortcut pressed while a session
   is still finishing is queued and starts as soon as it's done.
6. **Delivery.** `Delivery` pastes the text, then the screenshots, into the
   app that was in front when the recording stopped, if it still is. After a
   text-only note it restores the person's clipboard; a session with
   screenshots, or one it couldn't paste, stays on the clipboard.
7. **Feedback.** `RecordingReport` holds every message about a recording:
   the island's words, the menu's status line, and any notice that needs
   attention.

## State and settings

- `Settings` is the one observable store for preferences. SwiftUI views bind
  to it; AppKit parts register for the properties they react to.
- `Permissions` reads microphone, screen-recording, and accessibility access
  live from macOS and polls only while Setup is open.
- `SetupFlow` owns nothing but the current step of guided setup.
- `AppDelegate` builds the parts and connects them; behavior lives in the
  parts themselves.

## Repository map

```text
Sources/LinefeedCore/
  Brand/        palette and mark geometry shared by the app, icon, and website
  Permissions/  combining two microphone permission APIs
  Recording/    circle detection, trail segments, audio activity, outcomes, commands
  Sessions/     manifest, context timeline, folder naming, storage budget
  Shortcuts/    shortcut model, settings, and the recognition engine
  Text/         polishing, technical terms, vocabulary, timed transcripts

Sources/Linefeed/
  App/          lifecycle wiring, menu bar, notices, errors
  Brand/        colors, mark views, dot-matrix lettering, window chrome, controls
  Capture/      screenshots, trail overlay, pointer sampling
  Delivery/     clipboard formats and pasting into the target app
  History/      session storage and the History window
  Island/       the recording island
  Onboarding/   guided setup
  Permissions/  live permission state
  Recording/    recording lifecycle, audio, microphones, shortcuts, sounds
  Settings/     settings store and window
  Speech/       models, languages, transcription, cleanup, vocabulary

Tests/LinefeedCoreTests/   behavior of the core rules
Tests/LinefeedAppTests/    clipboard formats, storage, settings, cleanup guard
scripts/                   build, signing, packaging, brand assets
site/                      the website (React, TypeScript, Vite)
```

## Identity and signing

The bundle identifier `app.linefeed.desktop` and a stable code signature
matter because macOS ties privacy permissions to them. `build-app.sh` signs
with the local “Linefeed Local Development” identity from
`setup-signing-identity.sh` and falls back to ad-hoc signing. Apple
Intelligence support is weak-linked; the build fails if it isn't, so the app
keeps launching on macOS 14 and 15.
