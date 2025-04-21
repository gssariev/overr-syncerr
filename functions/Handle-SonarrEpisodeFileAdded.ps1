function Handle-SonarrEpisodeFileAdded {
    param ([psobject]$payload)

    $title = $payload.series.title
    $tmdbId = $payload.series.tmdbId
    $tvdbId = $payload.series.tvdbId
    $seasonNumber = $payload.episodes[0].seasonNumber
    $episodeNumber = $payload.episodes[0].episodeNumber

    Log-Message -Type "INF" -Message "New episode added: $title S$seasonNumber E$episodeNumber"

    if (-not $plexHost -or -not $plexToken) {
        Log-Message -Type "ERR" -Message "Plex host or token not set. Cannot proceed."
        return
    }

    $sectionIds = $seriesSectionIds
    $show = $null

    # Optional delay to allow Plex metadata to be fully available
    $delay = $env:SONARR_TRACK_DELAY_SECONDS
    if (-not $delay) { $delay = 10 }  # default to 10s if not set
    Log-Message -Type "INF" -Message "Waiting $delay seconds before applying track preferences..."
    Start-Sleep -Seconds $delay

    # Search for the show
    foreach ($sectionId in $sectionIds) {
        $searchUrl = "$plexHost/library/sections/$sectionId/all?type=2&title=" + [System.Uri]::EscapeDataString($title) + "&X-Plex-Token=$plexToken"
        try {
            $result = Invoke-RestMethod -Uri $searchUrl -Method Get -ContentType "application/xml"
            $matchedShow = $result.MediaContainer.Directory | Where-Object { $_.title -eq $title }
            if ($matchedShow) {
                $show = $matchedShow
                break
            }
        } catch {
            Log-Message -Type "ERR" -Message "Error searching Plex section ${sectionId}: $_"
        }
    }

    if (-not $show) {
        Log-Message -Type "ERR" -Message "Could not locate series '$title' in Plex."
        return
    }

    $showKey = $show.ratingKey

    # Fetch seasons
    $seasonsUrl = "$plexHost/library/metadata/$showKey/children"+"?X-Plex-Token=$plexToken"
    try {
        $seasonsMetadata = Invoke-RestMethod -Uri $seasonsUrl -Method Get -ContentType "application/xml"
    } catch {
        Log-Message -Type "ERR" -Message "Error retrieving seasons for '$title': $_"
        return
    }

    # Try to find the correct season by index
    $season = $seasonsMetadata.MediaContainer.Directory | Where-Object { $_.index -eq $seasonNumber }

    if (-not $season) {
        Log-Message -Type "ERR" -Message "Season $seasonNumber not found for '$title'"
        return
    }

    # Fetch episodes in the season
    $seasonKey = $season.ratingKey
    $episodesUrl = "$plexHost/library/metadata/$seasonKey/children"+"?X-Plex-Token=$plexToken"
    try {
        $episodesMetadata = Invoke-RestMethod -Uri $episodesUrl -Method Get -ContentType "application/xml"
    } catch {
        Log-Message -Type "ERR" -Message "Error retrieving episodes for season ${seasonNumber}: $_"
        return
    }

    # Find episode by index
    $episode = $episodesMetadata.MediaContainer.Video | Where-Object { $_.index -eq $episodeNumber }

    if (-not $episode) {
        Log-Message -Type "ERR" -Message "Episode S$seasonNumber E$episodeNumber not found in Plex for '$title'"
        return
    }

    $ratingKey = $episode.ratingKey
    Log-Message -Type "SUC" -Message "Found Plex episode ratingKey: $ratingKey"

    

    if ($enableAudioPref) {
        Set-AudioTrack -ratingKey $ratingKey 
        Set-SubtitleTrack -ratingKey $ratingKey 
    }
}
