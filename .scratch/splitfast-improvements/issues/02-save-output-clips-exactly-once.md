# Save Output Clips exactly once

Status: ready-for-agent

## Parent

`.scratch/splitfast-improvements/PRD.md`

## What to build

Save each complete Split Job exactly once to the fixed `SplitFast` Destination Album. Export clips to temporary storage first, then add them to the album only after every Output Clip exports successfully.

## Acceptance criteria

- [ ] Exporting no longer saves an Output Clip during each individual export step.
- [ ] Completed Split Jobs save all Output Clips once to the `SplitFast` Destination Album.
- [ ] Failed or canceled Split Jobs leave no partial Output Clips in the Destination Album.
- [ ] Temporary split files are cleaned up after success, failure, and cancellation.
- [ ] `xcodebuild -project SplitFast.xcodeproj -scheme SplitFast -destination 'generic/platform=iOS Simulator' build` succeeds.

## Blocked by

- `.scratch/splitfast-improvements/issues/01-safe-split-job-result-path.md`
