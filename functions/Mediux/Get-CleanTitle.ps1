function Get-CleanTitle {
    param ([string]$title)

    # Remove subtitles, symbols, and trailing colons
    $title = $title -replace '[:–\-|].*$', ''      # Remove anything after colon/dash/pipe
    $title = $title -replace '[^a-zA-Z0-9\s]', ''  # Remove special characters like ²
    $title = $title -replace '\s+', ' '            # Normalize whitespace
    return $title.Trim()
}
