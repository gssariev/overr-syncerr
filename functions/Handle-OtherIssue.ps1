function Handle-OtherIssue {
    param ([psobject]$payload)

    $subject = $payload.subject
    $label = $payload.issue.reportedBy_username
    $issueType = $payload.issue.issue_type
    $message = $payload.message
    $mediaType = $payload.media.media_type

    Write-Host "Extracted Label: $label"

    if ($mediaType -eq "movie") {
        $sectionId = $moviesSectionId
        $mediaTypeForSearch = "1"

        # API call to get movie title and release date
        $tmdbId = $payload.media.tmdbId
        $movieLookupUrl = "$overseerrUrl/movie/$tmdbId"
        Write-Host "Movie Lookup URL: $movieLookupUrl"
        try {
            $headers = @{
                'X-Api-Key' = $overseerrApiKey
            }
            $movieDetails = Invoke-RestMethod -Uri $movieLookupUrl -Method Get -Headers $headers
            $title = $movieDetails.title
            $releaseDate = $movieDetails.releaseDate
            $year = $releaseDate.Split('-')[0] # Extract year from release date
        } catch {
            Write-Host "Error fetching movie details: $_"
            return
        }
    } elseif ($mediaType -eq "tv") {
        $sectionId = $seriesSectionId
        $mediaTypeForSearch = "2"

        # API call to check seriesType and get series title and year
        $tmdbId = $payload.media.tmdbId
        $tvdbId = $payload.media.tvdbId

        if ($null -ne $tmdbId) {
            $seriesLookupUrl = "$overseerrUrl/service/sonarr/lookup/$tmdbId"
            Write-Host "Series Lookup URL (TMDB): $seriesLookupUrl"
        } elseif ($null -ne $tvdbId) {
            $seriesLookupUrl = "$overseerrUrl/service/sonarr/lookup/$tvdbId?type=tvdb"
            Write-Host "Series Lookup URL (TVDB): $seriesLookupUrl"
        } else {
            Write-Host "Both TMDB ID and TVDB ID are missing."
            return
        }

        try {
            $headers = @{
                'X-Api-Key' = $overseerrApiKey
            }
            $seriesDetails = Invoke-RestMethod -Uri $seriesLookupUrl -Method Get -Headers $headers
            $matchedSeries = $seriesDetails | Where-Object { $_.tmdbId -eq $tmdbId -or $_.tvdbId -eq $tvdbId }
            if ($null -eq $matchedSeries) {
                Write-Host "No matching series found for tmdbId: $tmdbId or tvdbId: $tvdbId"
                return
            }
            $title = $matchedSeries.title
            $year = $matchedSeries.year
            if ($matchedSeries.seriesType -eq "anime") {
                $sectionId = $animeSectionId
            }
        } catch {
            Write-Host "Error fetching series details: $_"
            return
        }
    } else {
        Write-Host "Unsupported media type: $mediaType"
        return
    }

    Write-Host "Extracted Title: $title"
    Write-Host "Extracted Year: $year"

    if (-not $plexToken -or -not $plexHost) {
        Write-Host "Plex host or token not set in environment variables"
        return
    }

    $searchUrl = "$plexHost/library/sections/$sectionId/all?type=$mediaTypeForSearch&title=" + [System.Uri]::EscapeDataString($title) + "&year=$year&X-Plex-Token=$plexToken"
    Write-Host "Search URL: $searchUrl"
    try {
        $mediaItems = Invoke-RestMethod -Uri $searchUrl -Method Get -ContentType "application/xml"
    } catch {
        Write-Host "Error contacting Plex server: $_"
        return
    }

    try {
        if ($mediaType -eq "movie") {
            $mediaItem = $mediaItems.MediaContainer.Video | Where-Object { $_.title -eq $title -and $_.year -eq $year }
        } elseif ($mediaType -eq "tv") {
            $mediaItem = $mediaItems.MediaContainer.Directory | Where-Object { $_.title -eq $title -and $_.year -eq $year }
        }
    } catch {
        Write-Host "Error parsing Plex server response: $_"
        return
    }

    if ($null -eq $mediaItem) {
        Write-Host "Media item not found after filtering"
        return
    }

    $ratingKey = $mediaItem.ratingKey
    Write-Host "Extracted Rating Key: $ratingKey"

    $metadataUrl = "$plexHost/library/metadata/$ratingKey" + "?X-Plex-Token=$plexToken"
    Write-Host "Metadata URL: $metadataUrl"
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

    if (-not ($currentLabels -contains $label)) {
        $currentLabels += $label
    }

    $encodedLabels = $currentLabels | ForEach-Object { "label[$($currentLabels.IndexOf($_))].tag.tag=" + [System.Uri]::EscapeDataString($_) }
    $encodedLabelsString = $encodedLabels -join "&"
    $updateUrl = "$plexHost/library/metadata/$ratingKey" + "?X-Plex-Token=$plexToken&$encodedLabelsString&label.locked=1"

    try {
        $responseResult = Invoke-RestMethod -Uri $updateUrl -Method Put
        Write-Host "Label added to media item: $($currentLabels -join ', ')"
        
        $message = "$subject is now available in your library"
        Post-OverseerrComment -issueId $payload.issue.issue_id -message $message -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
    } catch {
        Write-Host "Error adding label to media item: $_"
        Write-Host "Request URL: $updateUrl"
    }
}