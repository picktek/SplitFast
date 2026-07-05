# Prefer no-copy Source Video access

Status: ready-for-agent

## Parent

`.scratch/splitfast-improvements/PRD.md`

## What to build

Prefer durable no-copy Source Video access for picked videos and shared videos. Use PhotoKit asset access where available, try in-place file-provider reads where available, and copy the Source Video only when needed for reliable splitting.

## Acceptance criteria

- [ ] The main picker can identify Photos assets and request an AVAsset without first copying the Source Video when possible.
- [ ] File-provider sources attempt in-place access through coordinated reads when iOS provides it.
- [ ] Fallback copying happens only when no-copy access is unavailable or not durable enough for the requested Split Job.
- [ ] The UI/history can indicate when a Source Video had to be copied as a fallback.
- [ ] `xcodebuild -project SplitFast.xcodeproj -scheme SplitFast -destination 'generic/platform=iOS Simulator' build` succeeds.

## Blocked by

- `.scratch/splitfast-improvements/issues/01-safe-split-job-result-path.md`
