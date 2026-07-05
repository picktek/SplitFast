# iOS 26 Liquid Glass treatment

Status: ready-for-agent

## Parent

`.scratch/splitfast-improvements/PRD.md`

## What to build

Add native iOS 26 Liquid Glass treatment to the redesigned SplitFast UI while preserving a non-glass fallback for iOS 16.4-25. Use native SwiftUI glass APIs behind availability checks.

## Acceptance criteria

- [ ] iOS 26+ uses native SwiftUI Liquid Glass APIs for appropriate controls and surfaces.
- [ ] Glass effects are guarded with `#available(iOS 26, *)`.
- [ ] iOS 16.4-25 keeps a readable non-glass fallback UI.
- [ ] Interactive glass is used only for tappable/focusable elements.
- [ ] `xcodebuild -project SplitFast.xcodeproj -scheme SplitFast -destination 'generic/platform=iOS Simulator' build` succeeds.

## Blocked by

- `.scratch/splitfast-improvements/issues/07-video-first-single-screen-redesign.md`
