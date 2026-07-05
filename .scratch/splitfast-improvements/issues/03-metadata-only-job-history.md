# Metadata-only Job History

Status: ready-for-agent

## Parent

`.scratch/splitfast-improvements/PRD.md`

## What to build

Keep permanent Job History as local metadata only. Users should be able to review completed, failed, and canceled Split Jobs after leaving the active progress state, without SplitFast retaining Source Video copies.

## Acceptance criteria

- [ ] Completed, failed, canceled, and no-split-needed Split Jobs create Job History entries.
- [ ] Job History stores metadata only: status, timing, source name when available, Clip Length, clip count, and output asset identifiers when available.
- [ ] Job History does not store Source Video copies or durable retry access to Source Videos.
- [ ] Users can delete individual Job History entries and clear all Job History.
- [ ] `xcodebuild -project SplitFast.xcodeproj -scheme SplitFast -destination 'generic/platform=iOS Simulator' build` succeeds.

## Blocked by

- `.scratch/splitfast-improvements/issues/01-safe-split-job-result-path.md`
- `.scratch/splitfast-improvements/issues/02-save-output-clips-exactly-once.md`
