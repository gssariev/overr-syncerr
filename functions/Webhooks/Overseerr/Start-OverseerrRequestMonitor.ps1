function Start-OverseerrRequestMonitor {
    param (
        [string]$overseerrUrl,
        [string]$plexHost,
        [string]$plexToken,
        [string]$overseerrApiKey,
        [string]$seriesSectionId,
        [string]$animeSectionId
    )

    function Add-TagToMedia {
        param (
            [string]$newTag,
            [string]$ratingKey
        )

        $metadataUrl = "$plexHost/library/metadata/$ratingKey?X-Plex-Token=$plexToken"
        try {
            $metadata = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
        } catch {
            Write-Host "Error retrieving metadata: $_"
            return
        }

        $currentLabels = @()

        if ($metadata.MediaContainer.Video.Label) {
            $label = $metadata.MediaContainer.Video.Label
            $currentLabels = if ($label -is [System.Array]) { $label | ForEach-Object { $_.tag } } else { @($label.tag) }
        } elseif ($metadata.MediaContainer.Directory.Label) {
            $label = $metadata.MediaContainer.Directory.Label
            $currentLabels = if ($label -is [System.Array]) { $label | ForEach-Object { $_.tag } } else { @($label.tag) }
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

        $updateUrl = "$plexHost/library/metadata/$ratingKey?X-Plex-Token=$plexToken&$($encodedLabels -join '&')&label.locked=1"

        try {
            Invoke-RestMethod -Uri $updateUrl -Method Put
            Write-Host "Label '$newTag' added to media item $ratingKey."
        } catch {
            Write-Host "Failed to update tags for ratingKey ${ratingKey}: $_"
        }
    }

    try {
        $headers = @{ 'X-Api-Key' = $overseerrApiKey }
        $page = 1
        $take = 50
        $allRequests = @()
        $mediuxFilters = $env:MEDIUX_FILTERS -split ',' | ForEach-Object { $_.Trim().ToLower() }
        $cleanVersion = $env:MEDIUX_CLEAN_VERSION -eq 'true'

        do {
            $skip = ($page - 1) * $take
            $requestUrl = "$overseerrUrl/request?take=$take&skip=$skip&filter=all&sort=added&sortDirection=desc"
            Write-Host "Fetching page ${page}: $requestUrl"

            $response = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $headers
            if ($response.results) { $allRequests += $response.results }

            $hasMorePages = $page -lt $response.pageInfo.pages
            $page++
        } while ($hasMorePages)

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

                    if ("poster" -in $mediuxFilters -and $setInfo.assetUrl) {
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

                    if ("poster" -in $mediuxFilters -and $setInfo.assetUrl) {
                        Upload-Poster -ratingKey $ratingKey -posterUrl $setInfo.assetUrl -plexToken $plexToken -plexHost $plexHost
                    }

                    if ("season" -in $mediuxFilters -and $setInfo.seasonPosters) {
                        foreach ($poster in $setInfo.seasonPosters) {
                            Upload-SeasonPoster `
                                -ratingKey $ratingKey `
                                -seasonNumber $poster.season `
                                -posterUrl "https://api.mediux.pro/assets/$($poster.id)" `
                                -plexToken $plexToken `
                                -plexHost $plexHost
                        }
                    }

                    if ("titlecard" -in $mediuxFilters -and $setInfo.titleCards) {
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
