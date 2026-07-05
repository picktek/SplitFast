# SplitFast Improvement Plan

## Current App

SplitFast currently lets a user pick one video, choose a split duration, split the video into clips, and save results to Photos. The share extension can also receive a video and starts splitting immediately.

Known issues:

- Clips are saved twice: once into the `splitfast` album during export and again into Photos after export.
- The app promises short background continuation but does not implement a true background split flow.
- User-provided media paths and thumbnails are force-unwrapped in several places.
- Short videos silently do nothing.
- Share extension activation and processing are too broad for reliable long jobs.
- Progress, errors, completion, and history are transient.

## Agreed Product Shape

- Save each Output Clip exactly once, into the fixed `SplitFast` Destination Album.
- Prefer no-copy Source Video access through PhotoKit or in-place file-provider reads.
- Copy the Source Video only when iOS/provider limits make it necessary for reliable background splitting.
- Keep one Source Video per Split Job.
- Prioritize fast passthrough export and original quality over frame-perfect clip boundaries.
- Use all-or-nothing completion: save Output Clips only after every clip exports successfully.
- Show “no split needed” when the Source Video is already shorter than the selected Clip Length.
- Use Clip Length presets plus custom length.
- Keep permanent Job History as metadata only, with manual delete and clear-all.
- Ask for notification permission when starting a Background Split, not at launch.
- Keep iOS 16.4 as the minimum supported version.
- Use guarded iOS 26+ continued background processing and native Liquid Glass UI where available.
- Redesign the app as a single video-first screen, with Job History in a sheet.

## Implementation Sequence

1. Fix saving semantics.
   Remove the duplicate Photos save path, standardize the album name as `SplitFast`, and save completed clips once after all exports succeed.

2. Make splitting safer.
   Replace force unwraps with explicit failure states, handle short videos, and return structured Split Job results instead of progress sentinel values.

3. Introduce Split Job state.
   Add a small local model for active job progress, completion, failure, cancellation, and metadata-only Job History.

4. Rework source access.
   Configure PHPicker with `PHPhotoLibrary` for asset identifiers, use PhotoKit AVAsset access where possible, try in-place share-sheet reads with `NSFileCoordinator`, and copy only as fallback.

5. Rebuild share flow.
   Split inline only for readable in-place sources up to 3 minutes; otherwise hand off to the main app.

6. Add versioned background behavior.
   Keep foreground-first behavior on iOS 16.4-25 with clear warnings, and add iOS 26+ `BGContinuedProcessingTaskRequest` handling with progress reporting.

7. Redesign the main UI.
   Build a video-first single screen with preview, Clip Length presets/custom control, active Split Job status, completion state, and History sheet.

8. Add iOS 26 UI treatment.
   Use native Liquid Glass APIs behind `#available(iOS 26, *)`; keep non-glass fallback UI for older systems.

## First Coding Pass

Start with steps 1-3. They remove the real correctness bugs without depending on iOS 26 APIs or the full redesign.
