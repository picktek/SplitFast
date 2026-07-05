# Versioned background splitting

SplitFast will treat Background Split as a real product promise where the OS supports continued user-initiated processing, using iOS 26+ continued processing APIs for long splits. On unsupported systems, SplitFast will still allow splitting but warn the user that the app must stay open. This avoids the current false 30-second background promise while still taking the longer-running path available on newer iOS versions.
