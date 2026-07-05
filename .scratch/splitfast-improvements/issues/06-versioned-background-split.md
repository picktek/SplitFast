# Versioned Background Split

Status: resolved

## Parent

`.scratch/splitfast-improvements/PRD.md`

## What to build

Make Background Split a real versioned capability. On iOS 26+, use continued user-initiated background processing with progress reporting. On iOS 16.4-25, keep splitting available but warn users that the app must stay open.

## Acceptance criteria

- [ ] iOS 26+ starts eligible long Split Jobs through continued background processing APIs with progress reporting.
- [ ] iOS 16.4-25 shows an honest keep-app-open warning instead of promising background completion.
- [ ] Notification permission is requested when starting a Background Split, not on first launch.
- [ ] Background completion, failure, cancellation, and expiration update active UI and Job History.
- [ ] `xcodebuild -project SplitFast.xcodeproj -scheme SplitFast -destination 'generic/platform=iOS Simulator' build` succeeds.

## Blocked by

- `.scratch/splitfast-improvements/issues/01-safe-split-job-result-path.md`
- `.scratch/splitfast-improvements/issues/03-metadata-only-job-history.md`
- `.scratch/splitfast-improvements/issues/04-prefer-no-copy-source-video-access.md`
