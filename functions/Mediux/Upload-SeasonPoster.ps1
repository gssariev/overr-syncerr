function Upload-SeasonPoster {
    param (
        [Parameter(Mandatory)][string]$ratingKey,      # Show's ratingKey
        [Parameter(Mandatory)][int]$seasonNumber,
        [Parameter(Mandatory)][string]$posterUrl,
        [Parameter(Mandatory)][string]$plexToken,
        [Parameter(Mandatory)][string]$plexHost
    )

    # Step 1: Get season's ratingKey
    $seasonUrl = "$plexHost/library/metadata/$ratingKey/children?X-Plex-Token=$plexToken"
    try {
        $seasonMeta = Invoke-RestMethod -Uri $seasonUrl -Method Get -ContentType "application/xml"
        $seasonDir = $seasonMeta.MediaContainer.Directory | Where-Object { $_.index -eq $seasonNumber }
        if (-not $seasonDir) {
            Write-Warning "[WRN] Season $seasonNumber not found in Plex for ratingKey $ratingKey"
            return
        }
        $seasonRatingKey = $seasonDir.ratingKey
    } catch {
        Write-Warning "[WRN] Failed to get season metadata: $_"
        return
    }

    # Step 2: Upload poster to the season metadata
    $encodedUrl = [uri]::EscapeDataString($posterUrl)
    $requestUrl = "$plexHost/library/metadata/$seasonRatingKey/posters?url=$encodedUrl&X-Plex-Token=$plexToken"

    Write-Host "[INF] Uploading season $seasonNumber poster to ratingKey $seasonRatingKey..."
    Write-Host "[DBG] $requestUrl"

    try {
        Invoke-RestMethod -Method Post -Uri $requestUrl -Headers @{ "Accept" = "application/json" }
        Write-Host "[SUC] Season $seasonNumber poster uploaded successfully."
    } catch {
        Write-Warning "[WRN] Failed to upload season $seasonNumber poster: $_"
    }
}
