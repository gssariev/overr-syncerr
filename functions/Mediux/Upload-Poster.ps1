function Upload-Poster {
    param (
        [Parameter(Mandatory)][string]$ratingKey,
        [Parameter(Mandatory)][string]$posterUrl,
        [Parameter(Mandatory)][string]$plexToken,
        [Parameter(Mandatory)][string]$plexHost 
    )

    $encodedUrl = [uri]::EscapeDataString($posterUrl)
    $requestUrl = "$plexHost/library/metadata/$ratingKey/posters?url=$encodedUrl"+"&X-Plex-Token=$plexToken"

    Log-Message -Type "INF" -Message "Sending POST request to Plex to update poster:"
   

    try {
        Invoke-RestMethod -Method Post -Uri $requestUrl -Headers @{ "Accept" = "application/json" }
        Log-Message -Type "SUC" -Message "Poster updated successfully via URL."
    } catch {
        Log-Message -Type "ERR" -Message "Failed to set poster via URL: $_"
        return
    }

    # Check for 'overlay' label
    $metadataUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken"
    Log-Message -Type "INF" -Message "Checking for existing 'Overlay' label..."

    try {
        $metadata = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
    } catch {
        Log-Message -Type "ERR" -Message "Failed to fetch metadata to verify 'overlay' label: $_"
        return
    }

    # Parse labels correctly using `tag` attribute
    $labels = @()
    $labelElements = $metadata.MediaContainer.Video.Label
    if (-not $labelElements) {
        $labelElements = $metadata.MediaContainer.Directory.Label
    }

    if ($labelElements) {
        if ($labelElements -is [System.Array]) {
            $labels = $labelElements | ForEach-Object { $_.tag }
        } else {
            $labels = @($labelElements.tag)
        }
    }

    if ($labels -contains "Overlay") {
        Log-Message -Type "INF" -Message "Found label 'Overlay' — removing it now..."
        Remove-TagFromMedia -removeTag "Overlay" -ratingKeys @($ratingKey)
    } else {
        Log-Message -Type "INF" -Message "No 'Overlay' label found. Skipping removal."
    }
}
