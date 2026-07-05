# Share flow inline when safe

The Share Flow will split inline only when iOS provides readable in-place source access and the Source Video is at most 3 minutes long. Longer or less durable sources will hand off to the main app so progress, fallback copying, and background continuation have a real owner.
