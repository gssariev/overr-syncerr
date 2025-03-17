function Get-SubtitleText {
    param (
        [string]$subtitlePath
    )

    # Retrieve and normalize path mappings
    $moviePathMapping = $env:MOVIE_PATH_MAPPING -replace "\\", "/"
    $tvPathMapping = $env:TV_PATH_MAPPING -replace "\\", "/"
    $subtitlePath = $subtitlePath -replace "\\", "/"

    Log-Message -Type "INF" -Message "Received Subtitle Path: '$subtitlePath'"
    Log-Message -Type "DBG" -Message "Configured Movie Path Mapping: '$moviePathMapping'"
    Log-Message -Type "DBG" -Message "Configured TV Path Mapping: '$tvPathMapping'"

    # Match and replace paths
    if ($subtitlePath.StartsWith($moviePathMapping)) {
        $subtitlePath = $subtitlePath -replace [regex]::Escape($moviePathMapping), "/mnt/movies"
        Log-Message -Type "SUC" -Message "Mapped Subtitle Path to Movie Container Path: '$subtitlePath'"
    } elseif ($subtitlePath.StartsWith($tvPathMapping)) {
        $subtitlePath = $subtitlePath -replace [regex]::Escape($tvPathMapping), "/mnt/tv"
        Log-Message -Type "SUC" -Message "Mapped Subtitle Path to TV Container Path: '$subtitlePath'"
    } else {
        Log-Message -Type "ERR" -Message "No matching path found for the given subtitle path."
    }

    # Debugging before checking file existence
    Log-Message -Type "DBG" -Message "Checking file existence at path: '$subtitlePath'"

    # Verify file existence
    if (Test-Path -LiteralPath $subtitlePath) {
        Log-Message -Type "INF" -Message "Subtitle file exists: '$subtitlePath'"
        try {
            $subtitleText = Get-Content -LiteralPath $subtitlePath | Out-String
            return $subtitleText
        } catch {
            Log-Message -Type "ERR" -Message "Error reading subtitle file: $_"
            return $null
        }
    } else {
        Log-Message -Type "ERR" -Message "Subtitle file does NOT exist: '$subtitlePath'"
        return $null
    }
}
