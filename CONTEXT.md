# SplitFast

SplitFast turns a video into shorter clips and places the results where the user expects to find them.

## Language

**Source Video**:
The original video selected in the app or sent through the share extension.
_Avoid_: Input file, main file

**Output Clip**:
One shorter video produced from a Source Video.
_Avoid_: Part, chunk, segment

**Clip Length**:
The requested duration of each Output Clip.
_Avoid_: Part duration, chunk size

**Split Job**:
The user-started work of turning one Source Video into Output Clips.
_Avoid_: Process, task, export session

**Job History**:
A local record of recent Split Jobs and their outcomes.
_Avoid_: Export log, analytics, audit trail

**Share Flow**:
The path where the user starts SplitFast from the iOS share sheet.
_Avoid_: Share extension internals

**Background Split**:
A Split Job that the user expects to continue after leaving SplitFast.
_Avoid_: Best-effort background task, 30-second grace period

**Destination Album**:
The Photos album named `SplitFast` where SplitFast places complete Output Clips.
_Avoid_: Main library, Recents, camera roll
