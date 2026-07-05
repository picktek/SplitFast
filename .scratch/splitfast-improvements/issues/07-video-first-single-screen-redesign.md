# Video-first single-screen redesign

Status: ready-for-agent

## Parent

`.scratch/splitfast-improvements/PRD.md`

## What to build

Redesign SplitFast around a single video-first screen. The main screen should prioritize Source Video preview/selection, Clip Length presets plus custom length, active Split Job status, completion state, and access to Job History in a sheet.

## Acceptance criteria

- [ ] The first screen is the working splitter, not a landing page or tabbed dashboard.
- [ ] Clip Length is chosen through common presets plus a compact custom control.
- [ ] Active Split Job progress, cancellation, failure, no-split-needed, and completion states are visible and readable.
- [ ] Job History opens from a sheet and supports entry deletion and clear-all.
- [ ] The UI remains usable on iPhone and iPad sizes supported by the project.
- [ ] `xcodebuild -project SplitFast.xcodeproj -scheme SplitFast -destination 'generic/platform=iOS Simulator' build` succeeds.

## Blocked by

- `.scratch/splitfast-improvements/issues/01-safe-split-job-result-path.md`
- `.scratch/splitfast-improvements/issues/02-save-output-clips-exactly-once.md`
- `.scratch/splitfast-improvements/issues/03-metadata-only-job-history.md`
