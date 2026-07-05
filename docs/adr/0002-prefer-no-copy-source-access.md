# Prefer no-copy source access

SplitFast will avoid copying the Source Video when iOS can provide durable access through PhotoKit asset access or in-place file-provider reads. If a provider cannot keep the Source Video readable long enough for a reliable Split Job, SplitFast may copy the source as a fallback so background splitting and recovery still work.
