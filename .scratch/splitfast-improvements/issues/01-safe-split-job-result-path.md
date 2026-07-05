# Safe Split Job result path

Status: resolved

## Parent

`.scratch/splitfast-improvements/PRD.md`

## What to build

Make a Split Job report explicit completion, no-split-needed, cancellation, and failure states all the way to the UI. The app should stop relying on force unwraps and progress sentinel values for user/media paths.

## Acceptance criteria

- [ ] A Source Video shorter than the selected Clip Length shows a clear no-split-needed state and creates no Output Clips.
- [ ] Invalid media, missing thumbnails, failed duration loading, and canceled selection do not crash the app.
- [ ] Split Job progress, cancellation, completion, and failure are represented by named states instead of magic progress values.
- [ ] The main app and Share Flow both compile against the updated Split Job result path.
- [ ] `xcodebuild -project SplitFast.xcodeproj -scheme SplitFast -destination 'generic/platform=iOS Simulator' build` succeeds.

## Blocked by

None - can start immediately.
