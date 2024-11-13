function Get-SubtitlePath {
    param (
        [string]$subtitlePath,
        [string]$mediaType  # Should be either 'movie' or 'tv'
    )

    # Retrieve path mappings from environment variables
    $moviePathMapping = $env:MOVIE_PATH_MAPPING
    $tvPathMapping = $env:TV_PATH_MAPPING

    if ($mediaType -eq 'movie') {
        # Replace the matching part of the movie path with the Docker-mounted path
        $subtitlePath = $subtitlePath -replace [regex]::Escape($moviePathMapping), "/mnt/movies"
    } elseif ($mediaType -eq 'tv') {
        # Replace the matching part of the TV path with the Docker-mounted path
        $subtitlePath = $subtitlePath -replace [regex]::Escape($tvPathMapping), "/mnt/tv"
    }

    # Return the updated subtitle path with forward slashes
    return $subtitlePath -replace "\\", "/"
}