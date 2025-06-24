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
            Log-Message -Type "WRN" -Message "Season $seasonNumber not found."
            return
        }
        $seasonRatingKey = $seasonDir.ratingKey
    } catch {
        Log-Message -Type "ERR" -Message "Failed to fetch season metadata: $_"
        return
    }

    # Get episode ratingKey
    $episodeUrl = "$plexHost/library/metadata/$seasonRatingKey/children?X-Plex-Token=$plexToken"
    try {
        $episodeMeta = Invoke-RestMethod -Uri $episodeUrl -Method Get -ContentType "application/xml"
        $episodeDir = $episodeMeta.MediaContainer.Video | Where-Object { $_.index -eq $episodeNumber }
        if (-not $episodeDir) {
            Log-Message -Type "WRN" -Message "Episode S$seasonNumber E$episodeNumber not found."
            return
        }
        $episodeRatingKey = $episodeDir.ratingKey
    } catch {
        Log-Message -Type "WRN" -Message "Failed to fetch episode metadata: $_"
        return
    }

    # Upload title card
    $encodedUrl = [uri]::EscapeDataString($posterUrl)
    $requestUrl = "$plexHost/library/metadata/$episodeRatingKey/thumbs?url=$encodedUrl&X-Plex-Token=$plexToken"

    Log-Message -Type "INF" -Message "Uploading title card for S$seasonNumber E$episodeNumber..."

    try {
        Invoke-RestMethod -Method Post -Uri $requestUrl -Headers @{ "Accept" = "application/json" }
        Log-Message -Type "SUC" -Message "Title card uploaded for episode S$seasonNumber E$episodeNumber."
    } catch {
        Log-Message -Type "ERR" -Message "Failed to upload title card: $_"
    }
}
