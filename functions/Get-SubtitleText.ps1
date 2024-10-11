function Get-SubtitleText {
    param (
        [string]$subtitlePath
    )

    # Retrieve environment variables for path mappings
    $moviePathMapping = $env:MOVIE_PATH_MAPPING
    $tvPathMapping = $env:TV_PATH_MAPPING

    Write-Host "Received Subtitle Path: $subtitlePath"
    Write-Host "Movie Path Mapping: $moviePathMapping"
    Write-Host "TV Path Mapping: $tvPathMapping"

    # Check if the subtitlePath matches movie or tv path mappings
    if ($subtitlePath -like "$moviePathMapping\*") {
        Write-Host "Matching Movie Path Found. Replacing '$moviePathMapping' with '/mnt/movies'"
        $subtitlePath = $subtitlePath -replace [regex]::Escape($moviePathMapping), "/mnt/movies"
    } elseif ($subtitlePath -like "$tvPathMapping\*") {
        Write-Host "Matching TV Path Found. Replacing '$tvPathMapping' with '/mnt/tv'"
        $subtitlePath = $subtitlePath -replace [regex]::Escape($tvPathMapping), "/mnt/tv"
    } else {
        Write-Host "No matching path found for the given subtitle path."
    }

    # Ensure the path uses Linux format
    $subtitlePath = $subtitlePath -replace "\\", "/"

    Write-Host "Mapped Subtitle Path: $subtitlePath"

    try {
        # Use -LiteralPath to handle special characters in the file name
        $subtitleText = Get-Content -LiteralPath $subtitlePath | Out-String
        return $subtitleText
    } catch {
        Write-Host "Failed to read subtitle file: $_"
        return $null
    }
}
