function Set-SubtitleText {
    param (
        [string]$subtitlePath,
        [string]$text,
        [string]$targetLang
    )

    # Retrieve environment variables for path mappings
    $moviePathMapping = $env:MOVIE_PATH_MAPPING
    $tvPathMapping = $env:TV_PATH_MAPPING

    Write-Host "Received Subtitle Path for saving: $subtitlePath"
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

    # Extract file name and path details
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($subtitlePath)  # Get the file name without extension
    $directoryPath = [System.IO.Path]::GetDirectoryName($subtitlePath)        # Get the directory path

    # Extract the original language code by checking the last two or three characters before the extension
    if ($fileName -match "\.\w{2,3}$") {
        # Remove the last language code (whether 2 or 3 characters) and replace it with the target language
        $fileName = $fileName -replace "\.\w{2,3}$", ""
    }

    # Build the new file name by appending the target language code
    $newSubtitlePath = [System.IO.Path]::Combine($directoryPath, "$fileName.$targetLang.srt")

    try {
        # Ensure the directory exists, if not, create it
        if (-not (Test-Path -Path $directoryPath)) {
            New-Item -ItemType Directory -Path $directoryPath | Out-Null
            Write-Host "Created missing directory: $directoryPath"
        }

        # Save the subtitle file using -LiteralPath to handle special characters
        Set-Content -LiteralPath $newSubtitlePath -Value $text
        Write-Host "Successfully saved subtitle file: $newSubtitlePath"
    } catch {
        Write-Host "Failed to write to subtitle file: $_"
    }
}
