function Set-SubtitleText {
    param (
        [string]$subtitlePath,
        [string]$text,
        [string]$targetLang
    )

    # Retrieve and sanitize environment variables
    $moviePathMapping = $env:MOVIE_PATH_MAPPING -replace "\\", "/" -replace "\s+$", ""
    $tvPathMapping = $env:TV_PATH_MAPPING -replace "\\", "/" -replace "\s+$", ""

    # Normalize subtitle path
    $subtitlePath = $subtitlePath -replace "\\", "/"

    # Debugging output before path replacement
    Write-Host "DEBUG: Checking '$subtitlePath' against '$moviePathMapping'"
    Write-Host "DEBUG: Checking '$subtitlePath' against '$tvPathMapping'"

    # Match and replace paths
    if ($subtitlePath.StartsWith($moviePathMapping)) {
        Write-Host "DEBUG: Movie path detected. Replacing '$moviePathMapping' with '/mnt/movies'"
        $subtitlePath = $subtitlePath -replace [regex]::Escape($moviePathMapping), "/mnt/movies"
    } elseif ($subtitlePath.StartsWith($tvPathMapping)) {
        Write-Host "DEBUG: TV path detected. Replacing '$tvPathMapping' with '/mnt/tv'"
        $subtitlePath = $subtitlePath -replace [regex]::Escape($tvPathMapping), "/mnt/tv"
    } else {
        Write-Host "ERROR: No matching path found for subtitle path."
    }

    # Extract file name and directory path
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($subtitlePath)
    $directoryPath = [System.IO.Path]::GetDirectoryName($subtitlePath)

    # Extract and replace language code
    if ($fileName -match "\.\w{2,3}$") {
        $fileName = $fileName -replace "\.\w{2,3}$", ""
    }

    # Build new subtitle path
    $newSubtitlePath = [System.IO.Path]::Combine($directoryPath, "$fileName.$targetLang.srt")

    try {
        # Ensure directory exists
        if (-not (Test-Path -Path $directoryPath)) {
            New-Item -ItemType Directory -Path $directoryPath | Out-Null
            Write-Host "Created missing directory: $directoryPath"
        }

        # Save the subtitle file
        Set-Content -LiteralPath $newSubtitlePath -Value $text
        Write-Host "Successfully saved subtitle file: $newSubtitlePath"
    } catch {
        Write-Host "Failed to write to subtitle file: $_"
    }
}
