function Start-OverseerrRequestMonitor {
    param (
        [string]$overseerrUrl,
        [string]$plexHost,
        [string]$plexToken,
        [string]$overseerrApiKey,
        [string]$seriesSectionId,
        [string]$animeSectionId,
        [bool]$cleanVersion
    )

    function Add-TagToMedia {
        param (
            [string]$newTag,
            [string]$ratingKey
        )
    
        $metadataUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken"
        try {
            $metadata = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
        } catch {
            Write-Host "Error retrieving metadata: $_"
            return
        }
    
        $currentLabels = @()
    
        if ($metadata.MediaContainer.Video.Label) {
            if ($metadata.MediaContainer.Video.Label -is [System.Array]) {
                $currentLabels = $metadata.MediaContainer.Video.Label | ForEach-Object { $_.tag }
            } else {
                $currentLabels = @($metadata.MediaContainer.Video.Label.tag)
            }
        } elseif ($metadata.MediaContainer.Directory.Label) {
            if ($metadata.MediaContainer.Directory.Label -is [System.Array]) {
                $currentLabels = $metadata.MediaContainer.Directory.Label | ForEach-Object { $_.tag }
            } else {
                $currentLabels = @($metadata.MediaContainer.Directory.Label.tag)
            }
        }
    
        if (-not ($currentLabels -contains $newTag)) {
            $currentLabels += $newTag
        } else {
            Write-Host "Label '$newTag' already exists. Skipping."
            return
        }
    
        $encodedLabels = $currentLabels | ForEach-Object {
            $index = $currentLabels.IndexOf($_)
            "label[$index].tag.tag=" + [System.Uri]::EscapeDataString($_)
        }
    
        $encodedLabelsString = $encodedLabels -join "&"
        $updateUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken&$encodedLabelsString&label.locked=1"
    
        try {
            Invoke-RestMethod -Uri $updateUrl -Method Put
            Write-Host "Label '$newTag' added to media item $ratingKey."
        } catch {
            Write-Host "Failed to update tags for ratingKey ${ratingKey}: $_"
            Write-Host "Request URL: $updateUrl"
        }
    }
    
    try {
        $headers = @{ 'X-Api-Key' = $overseerrApiKey }
        $page = 1
        $take = 50
        $allRequests = @()

        do {
            $skip = ($page - 1) * $take
            $requestUrl = "$overseerrUrl/request?take=$take&skip=$skip&filter=all&sort=added&sortDirection=desc"
            Write-Host "Fetching page ${page}: $requestUrl"

            $response = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $headers

            if ($response.results) {
                $allRequests += $response.results
            }

            $hasMorePages = $page -lt $response.pageInfo.pages
            $page++

        } while ($hasMorePages)

        if (-not $allRequests) {
            Write-Host "No requests found."
            return
        }

        $matchingRequests = $allRequests | Where-Object { $_.media.status -in 4, 5 }

        if (-not $matchingRequests) {
            Write-Host "No approved or available requests to process."
            return
        }

        foreach ($request in $matchingRequests) {
            $mediaType = $request.media.mediaType
            $tmdbId = $request.media.tmdbId
            $tvdbId = $request.media.tvdbId
            $plexUsername = $request.requestedBy.plexUsername
            $ratingKey = $request.media.ratingKey

            if (-not $ratingKey) {
                Write-Host "Skipping item with no ratingKey."
                continue
            }

            Write-Host "Processing $mediaType (ratingKey: $ratingKey) for user: $plexUsername"

            Add-TagToMedia -newTag $plexUsername -ratingKey $ratingKey
            Set-AudioTrack -ratingKey $ratingKey -seriesSectionId $seriesSectionId -animeSectionId $animeSectionId
            Set-SubtitleTrack -ratingKey $ratingKey -seriesSectionId $seriesSectionId -animeSectionId $animeSectionId

            try {
    if ($mediaType -eq "movie") {
        $movieDetailsUrl = "$overseerrUrl/movie/$tmdbId"
        $movieDetails = Invoke-RestMethod -Uri $movieDetailsUrl -Headers $headers
        $title = $movieDetails.title
        $year = $movieDetails.releaseDate.Split('-')[0]

        $setInfo = Get-MediuxSetId `
            -tmdbId $tmdbId `
            -preferredUsernames ($env:MEDIUX_PREFERRED_USERNAMES -split ',') `
            -title $title `
            -year $year `
            -cleanVersion $cleanVersion

        if ($setInfo -and $setInfo.assetUrl) {
            Upload-Poster -ratingKey $ratingKey -posterUrl $setInfo.assetUrl -plexToken $plexToken -plexHost $plexHost
        }
    }

    elseif ($mediaType -eq "tv") {
        $seriesLookupUrl = "$overseerrUrl/service/sonarr/lookup/$tmdbId"
        $seriesResults = Invoke-RestMethod -Uri $seriesLookupUrl -Headers $headers
        $matched = $seriesResults | Where-Object { $_.tmdbId -eq $tmdbId }
        if (-not $matched) { continue }

        $title = $matched.title
        $year = $matched.year

        $setInfo = Get-MediuxShowSets `
            -tmdbId $tmdbId `
            -preferredUsernames ($env:MEDIUX_PREFERRED_USERNAMES -split ',') `
            -title $title `
            -year $year `
            -cleanVersion $cleanVersion

        if ($setInfo -and $setInfo.assetUrl) {
            Upload-Poster -ratingKey $ratingKey -posterUrl $setInfo.assetUrl -plexToken $plexToken -plexHost $plexHost
        }

        foreach ($poster in $setInfo.seasonPosters) {
            Upload-SeasonPoster `
                -ratingKey $ratingKey `
                -seasonNumber $poster.season `
                -posterUrl "https://api.mediux.pro/assets/$($poster.id)" `
                -plexToken $plexToken `
                -plexHost $plexHost
        }

        foreach ($tc in $setInfo.titleCards) {
            Upload-TitleCard `
                -showRatingKey $ratingKey `
                -seasonNumber $tc.season `
                -episodeNumber $tc.episode `
                -posterUrl "https://api.mediux.pro/assets/$($tc.id)" `
                -plexToken $plexToken `
                -plexHost $plexHost
        }
    }
} catch {
    Write-Warning "[WRN] Failed to apply Mediux artwork for $mediaType (ratingKey $ratingKey): $_"
}

        }

        Write-Host "Finished processing all Overseerr partially available and available requests."

    } catch {
        Write-Host "An error occurred while processing Overseerr requests: $_"
    }
}
