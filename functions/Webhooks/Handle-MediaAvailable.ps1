function Handle-MediaAvailable {
    param ([psobject]$payload)
	
    # Ensure Media Available handling is enabled
    if (-not $enableMediaAvailableHandling) {
        Log-Message -Type "WRN" -Message "Media Available handling is disabled."
        return
    }
	
    # Extract relevant information from the payload
    $mediaType = $payload.media.media_type
    $tmdbId = $payload.media.tmdbId
    $tvdbId = $payload.media.tvdbId
    $plexUsername = $payload.request.requestedBy_username

    Log-Message -Type "INF" -Message "Processing $mediaType request for Plex user: $plexUsername with TMDB ID: $tmdbId"

    # Ensure that Plex host and token are set
    if (-not $plexHost -or -not $plexToken) {
        Log-Message -Type "ERR" -Message "Plex host or token not set. Cannot proceed."
        return
    }

    # Handling movies
    if ($mediaType -eq "movie") {
        $sectionIds = $moviesSectionIds
        $mediaTypeForSearch = "1"  # Movie type for Plex API

        # API call to get movie title and release date
        $movieLookupUrl = "$overseerrUrl/movie/$tmdbId"
        Log-Message -Type "INF" -Message "Movie Lookup URL: $movieLookupUrl"
        try {
            $headers = @{
                'X-Api-Key' = $overseerrApiKey
            }
            $movieDetails = Invoke-RestMethod -Uri $movieLookupUrl -Method Get -Headers $headers
            $title = $movieDetails.title
            $releaseDate = $movieDetails.releaseDate
            $year = $releaseDate.Split('-')[0]  # Extract year from release date
        } catch {
            Log-Message -Type "ERR" -Message "Error fetching movie details: $_"
            return
        }
    }

     # Skip TV logic if Sonarr handler is enabled
     elseif ($mediaType -eq "tv" -and $enableSonarrEpisodeHandler) {
        Log-Message -Type "WRN" -Message "TV handling skipped due to Sonarr episode handler being enabled."
        return
    }

    # Handling TV shows (including anime)
    elseif ($mediaType -eq "tv") {
        $sectionIds = $seriesSectionIds
        $mediaTypeForSearch = "2"  # TV type for Plex API

        # API call to check seriesType and get series title and year
        if ($null -ne $tmdbId) {
            $seriesLookupUrl = "$overseerrUrl/service/sonarr/lookup/$tmdbId"
            Log-Message -Type "INF" -Message "Series Lookup URL (TMDB): $seriesLookupUrl"
        } elseif ($null -ne $tvdbId) {
            $seriesLookupUrl = "$overseerrUrl/service/sonarr/lookup/$tvdbId?type=tvdb"
            Log-Message -Type "INF" -Message "Series Lookup URL (TVDB): $seriesLookupUrl"
        } else {
            Log-Message -Type "ERR" -Message "Both TMDB ID and TVDB ID are missing."
            return
        }

        try {
            $headers = @{
                'X-Api-Key' = $overseerrApiKey
            }
            $seriesDetails = Invoke-RestMethod -Uri $seriesLookupUrl -Method Get -Headers $headers
            $matchedSeries = $seriesDetails | Where-Object { $_.tmdbId -eq $tmdbId -or $_.tvdbId -eq $tvdbId }
            if ($null -eq $matchedSeries) {
                Log-Message -Type "ERR" -Message "No matching series found for tmdbId: $tmdbId or tvdbId: $tvdbId"
                return
            }
            $title = $matchedSeries.title
            $year = $matchedSeries.year
            if ($matchedSeries.seriesType -eq "anime") {
                $sectionIds = $animeSectionIds
            }
        } catch {
            Log-Message -Type "ERR" -Message "Error fetching series details: $_"
            return
        }
    } else {
        Log-Message -Type "ERR" -Message "Unsupported media type: $mediaType"
        return
    }

    Log-Message -Type "SUC" -Message "Extracted Title: $title"
    Log-Message -Type "SUC" -Message "Extracted Year: $year"

$mediaItem = $null

foreach ($sectionId in $sectionIds) {
    try {
        $searchUrl = "$plexHost/library/sections/$sectionId/all?type=$mediaTypeForSearch"+"&X-Plex-Token=$plexToken"
        $mediaItems = Invoke-RestMethod -Uri $searchUrl -Method Get -ContentType "application/xml"

        # 1. Try to match by TMDB ID
        if ($tmdbId) {
            if ($mediaType -eq "movie" -and $mediaItems.MediaContainer.Video) {
                $mediaItem = $mediaItems.MediaContainer.Video | Where-Object { $_.Guid -match "tmdb://$tmdbId" }
            } elseif ($mediaType -eq "tv" -and $mediaItems.MediaContainer.Directory) {
                $mediaItem = $mediaItems.MediaContainer.Directory | Where-Object { $_.Guid -match "tmdb://$tmdbId" }
            }
        }

        # 2. If not found, try by TVDB ID
        if (-not $mediaItem -and $tvdbId) {
            if ($mediaType -eq "movie" -and $mediaItems.MediaContainer.Video) {
                $mediaItem = $mediaItems.MediaContainer.Video | Where-Object { $_.Guid -match "tvdb://$tvdbId" }
            } elseif ($mediaType -eq "tv" -and $mediaItems.MediaContainer.Directory) {
                $mediaItem = $mediaItems.MediaContainer.Directory | Where-Object { $_.Guid -match "tvdb://$tvdbId" }
            }
        }

        # 3. If still not found, try by Title & Year
        if (-not $mediaItem) {
            if ($mediaType -eq "movie" -and $mediaItems.MediaContainer.Video) {
                $mediaItem = $mediaItems.MediaContainer.Video | Where-Object { $_.title -eq $title -and $_.year -eq $year }
            } elseif ($mediaType -eq "tv" -and $mediaItems.MediaContainer.Directory) {
                $mediaItem = $mediaItems.MediaContainer.Directory | Where-Object { $_.title -eq $title -and $_.year -eq $year }
            }
        }

        if ($mediaItem) { break }  # Stop searching once we find the media

    } catch {
        Log-Message -Type "ERR" -Message "Error contacting Plex server for section ID ${sectionId}: $_"
    }
}

if ($null -eq $mediaItem) {
    Log-Message -Type "ERR" -Message "Media item not found in any section (TMDB, TVDB, Title/Year)."
    return
}

    # Ensure extracted rating keys are stored as an array
$ratingKeys = @()
if ($mediaItem -is [System.Array]) {
    $ratingKeys = $mediaItem.ratingKey
} else {
    $ratingKeys += $mediaItem.ratingKey
}

Log-Message -Type "SUC" -Message "Extracted Rating Keys: $($ratingKeys -join ', ')"

# Call Add-TagToMedia with the appropriate parameters
Add-TagToMedia -newTag $plexUsername -ratingKeys $ratingKeys

# Apply preferred audio and subtitle settings for each rating key
if ($enableAudioPref) {
    foreach ($ratingKey in $ratingKeys) {
        Set-AudioTrack -ratingKey $ratingKey -plexUsername $plexUsername
    }
}

if ($enableSubtitlePref) {
    foreach ($ratingKey in $ratingKeys) {
        Set-SubtitleTrack -ratingKey $ratingKey -plexUsername $plexUsername
    }
}

if ($enableMediux) {
# Apply posters from Mediux
if ($mediaType -eq "movie") {
    $setInfo = Get-MediuxMovieSetId `
    -tmdbId $tmdbId `
    -preferredUsernames ($env:MEDIUX_PREFERRED_USERNAMES -split ',') `
    -title $title `
    -year $year `
    -cleanVersion $cleanVersion


    if ($setInfo) {
    $posterUrl = $setInfo.assetUrl
    if ($posterUrl) {
        foreach ($ratingKey in $ratingKeys) {
            Upload-Poster `
                -ratingKey $ratingKey `
                -posterUrl $posterUrl `
                -plexToken $plexToken `
                -plexHost $plexHost
        }
    } else {
        Log-Message -Type "WRN" -Message "No Mediux artwork URL found for TMDB ID $tmdbId"
        foreach ($ratingKey in $ratingKeys) {
    Add-MissingPosterEntry `
        -showTitle $title `
        -ratingKey $ratingKey `
        -season $null `
        -episode $null `
        -tmdbId $tmdbId `
        -setId ($setInfo ? $setInfo.setId : $null) `
        -missingItems @("poster") `
        -year $year
}

    }
} else {
    Log-Message -Type "WRN" -Message "No Mediux set found for TMDB ID $tmdbId"
    foreach ($ratingKey in $ratingKeys) {
    Add-MissingPosterEntry `
        -showTitle $title `
        -ratingKey $ratingKey `
        -season $null `
        -episode $null `
        -tmdbId $tmdbId `
        -setId $null `
        -missingItems @("poster") `
        -year $year
}

}

}

elseif ($mediaType -eq "tv") {
    $setInfo = Get-MediuxShowSets `
        -tmdbId $tmdbId `
        -preferredUsernames ($env:MEDIUX_PREFERRED_USERNAMES -split ',') `
        -title $title `
        -year $year `
        -cleanVersion $cleanVersion

    foreach ($ratingKey in $ratingKeys) {
        if ($setInfo) {
            if ($setInfo.assetUrl) {
                Upload-Poster `
                    -ratingKey $ratingKey `
                    -posterUrl $setInfo.assetUrl `
                    -plexToken $plexToken `
                    -plexHost $plexHost
            }
            foreach ($seasonPoster in $setInfo.seasonPosters) {
                Upload-SeasonPoster `
                    -ratingKey $ratingKey `
                    -seasonNumber $seasonPoster.season `
                    -posterUrl "https://api.mediux.pro/assets/$($seasonPoster.id)" `
                    -plexToken $plexToken `
                    -plexHost $plexHost
            }
            foreach ($titleCard in $setInfo.titleCards) {
                Upload-TitleCard `
                    -showRatingKey $ratingKey `
                    -seasonNumber $titleCard.season `
                    -episodeNumber $titleCard.episode `
                    -posterUrl "https://api.mediux.pro/assets/$($titleCard.id)" `
                    -plexToken $plexToken `
                    -plexHost $plexHost
            }
        } else {
            Log-Message -Type "WRN" -Message "No Mediux show sets found for TMDB ID $tmdbId"
        }

        # --- NEW: Compare with Plex, log missing titlecards/posters ---
        $episodesUrl = "$plexHost/library/metadata/$ratingKey/allLeaves?X-Plex-Token=$plexToken"
        $episodesMetadata = Invoke-RestMethod -Uri $episodesUrl -Method Get -ContentType "application/xml"
        $plexEpisodes = @($episodesMetadata.MediaContainer.Video)

        $allSeasons = $plexEpisodes | Select-Object -ExpandProperty parentIndex -Unique

        foreach ($seasonNum in $allSeasons) {
            # Check if a season poster exists for this season in Mediux set
            $hasPoster = $setInfo -and $setInfo.seasonPosters -and ($setInfo.seasonPosters | Where-Object { $_.season -eq $seasonNum })
            if (-not $hasPoster) {
                Add-MissingPosterEntry `
                    -showTitle $title `
                    -ratingKey $ratingKey `
                    -season $seasonNum `
                    -episode $null `
                    -tmdbId $tmdbId `
                    -setId ($setInfo ? $setInfo.setId : $null) `
                    -missingItems @("season")
            }
        }

        

        foreach ($ep in $plexEpisodes) {
            $seasonNum = $ep.parentIndex
            $epNum = $ep.index
            # Check if a title card exists for this episode in Mediux set
            $hasTitleCard = $setInfo -and $setInfo.titleCards -and ($setInfo.titleCards | Where-Object { $_.season -eq $seasonNum -and $_.episode -eq $epNum })
            if (-not $hasTitleCard) {
                Add-MissingPosterEntry `
                    -showTitle $title `
                    -ratingKey $ratingKey `
                    -season $seasonNum `
                    -episode $epNum `
                    -tmdbId $tmdbId `
                    -setId ($setInfo ? $setInfo.setId : $null) `
                    -missingItems @("titlecard")
            }
        }

    }
}
}

}