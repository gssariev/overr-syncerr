function Get-SubtitlePath {
    param (
        [string]$subtitlePath,
        [string]$mediaType  # Should be either 'movie' or 'tv'
    )

    # Retrieve and sanitize environment variables
    $moviePathMapping = $env:MOVIE_PATH_MAPPING -replace "\\", "/" -replace "\s+$", ""
    $tvPathMapping = $env:TV_PATH_MAPPING -replace "\\", "/" -replace "\s+$", ""

    # Normalize subtitle path
    $subtitlePath = $subtitlePath -replace "\\", "/"


    # Path matching logic (simplified)
    if ($mediaType -eq 'movie' -and $subtitlePath.StartsWith($moviePathMapping)) {
        $subtitlePath = $subtitlePath -replace [regex]::Escape($moviePathMapping), "/mnt/movies"
        Log-Message -Type "SUC" -Message "Mapped Movie Subtitle Path: '$subtitlePath'"
    } elseif ($mediaType -eq 'tv' -and $subtitlePath.StartsWith($tvPathMapping)) {
        $subtitlePath = $subtitlePath -replace [regex]::Escape($tvPathMapping), "/mnt/tv"
        Log-Message -Type "SUC" -Message "Mapped TV Subtitle Path: '$subtitlePath'"
    } else {
        Log-Message -Type "ERR" -Message "No matching path found for media type '$mediaType'."
    }

    return $subtitlePath
}
