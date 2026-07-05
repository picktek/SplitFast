# Share Flow inline when safe

Status: resolved

## Parent

`.scratch/splitfast-improvements/PRD.md`

## What to build

Make the Share Flow split inline only when the Source Video is readable in place and at most 3 minutes long. Longer or less durable sources should hand off to the main app so progress, fallback copying, and background continuation have a real owner.

## Acceptance criteria

- [ ] The share extension activation path is limited to movie/video inputs.
- [ ] Shared Source Videos at most 3 minutes long can split inline when readable in place.
- [ ] Shared Source Videos longer than 3 minutes do not start a long inline extension Split Job.
- [ ] Sources that are not safely readable in place hand off to the main app instead of failing silently.
- [ ] `xcodebuild -project SplitFast.xcodeproj -scheme SplitFast -destination 'generic/platform=iOS Simulator' build` succeeds.

## Blocked by

- `.scratch/splitfast-improvements/issues/01-safe-split-job-result-path.md`
- `.scratch/splitfast-improvements/issues/04-prefer-no-copy-source-video-access.md`
