function Upload-TitleCard {
    param (
        [Parameter(Mandatory)][string]$showRatingKey,
        [Parameter(Mandatory)][int]$seasonNumber,
        [Parameter(Mandatory)][int]$episodeNumber,
        [Parameter(Mandatory)][string]$posterUrl,
        [Parameter(Mandatory)][string]$plexToken,
        [Parameter(Mandatory)][string]$plexHost
    )

    # Get season ratingKey
    $seasonUrl = "$plexHost/library/metadata/$showRatingKey/children?X-Plex-Token=$plexToken"
    try {
        $seasonMeta = Invoke-RestMethod -Uri $seasonUrl -Method Get -ContentType "application/xml"
        $seasonDir = $seasonMeta.MediaContainer.Directory | Where-Object { $_.index -eq $seasonNumber }
        if (-not $seasonDir) {
            Write-Warning "[WRN] Season $seasonNumber not found."
            return
        }
        $seasonRatingKey = $seasonDir.ratingKey
    } catch {
        Write-Warning "[WRN] Failed to fetch season metadata: $_"
        return
    }

    # Get episode ratingKey
    $episodeUrl = "$plexHost/library/metadata/$seasonRatingKey/children?X-Plex-Token=$plexToken"
    try {
        $episodeMeta = Invoke-RestMethod -Uri $episodeUrl -Method Get -ContentType "application/xml"
        $episodeDir = $episodeMeta.MediaContainer.Video | Where-Object { $_.index -eq $episodeNumber }
        if (-not $episodeDir) {
            Write-Warning "[WRN] Episode S$seasonNumber E$episodeNumber not found."
            return
        }
        $episodeRatingKey = $episodeDir.ratingKey
    } catch {
        Write-Warning "[WRN] Failed to fetch episode metadata: $_"
        return
    }

    # Upload title card
    $encodedUrl = [uri]::EscapeDataString($posterUrl)
    $requestUrl = "$plexHost/library/metadata/$episodeRatingKey/thumbs?url=$encodedUrl&X-Plex-Token=$plexToken"

    Write-Host "[INF] Uploading title card for S$seasonNumber E$episodeNumber..."
    Write-Host "[DBG] $requestUrl"

    try {
        Invoke-RestMethod -Method Post -Uri $requestUrl -Headers @{ "Accept" = "application/json" }
        Write-Host "[SUC] Title card uploaded for episode S$seasonNumber E$episodeNumber."
    } catch {
        Write-Warning "[WRN] Failed to upload title card: $_"
    }
}
