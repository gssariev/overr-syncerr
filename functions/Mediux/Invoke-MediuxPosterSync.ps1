function Invoke-MediuxPosterSync {
    param (
        [string]$title,             # Show or movie title
        [string]$ratingKey,         # Show or movie ratingKey
        [string]$mediaType,         # "show" or "movie"
        [Nullable[int]]$tmdbId = $null,
        [Nullable[int]]$year = $null,
        [Nullable[int]]$season = $null,   
        [Nullable[int]]$episode = $null    
    )

    try {
        $type = $mediaType.ToLower()
        $mediuxFilters = $env:MEDIUX_FILTERS -split ',' | ForEach-Object { $_.Trim().ToLower() }
        $preferredUsernames = $env:MEDIUX_PREFERRED_USERNAMES -split ',' | ForEach-Object { $_.Trim() }
        

        if ($type -eq "show") {
            # --- 1. Per-episode/season logic if both specified ---
            if ($season -and $episode) {
                # TMDB lookup if not provided
                if (-not $tmdbId) {
                    # Use first episode to extract parent (show) TMDB ID
$episodesUrl = "$plexHost/library/metadata/$ratingKey/allLeaves?X-Plex-Token=$plexToken"
$episodesXml = Invoke-RestMethod -Uri $episodesUrl -Method Get -ContentType "application/xml"

$firstEp = $episodesXml.MediaContainer.Video | Sort-Object addedAt | Select-Object -First 1
if (-not $firstEp) {
    Log-Message -Type "WRN" -Message "No episodes found for show: $title"
    return
}

$parentKey = $firstEp.grandparentRatingKey
$metadataUrl = "$plexHost/library/metadata/$parentKey?X-Plex-Token=$plexToken"
$guid = $firstEp.guid
if ($guid -match "tmdb://(\d+)") {
    $tmdbId = [int]$matches[1]
} else {
    Log-Message -Type "WRN" -Message "TMDB ID not found in episode GUID: $guid"
    return
}
                }
                if (-not $tmdbId) {
                    Log-Message -Type "WRN" -Message "TMDB ID not found for show: $title"
                    return
                }

                $setInfo = Get-MediuxShowSets -tmdbId $tmdbId -title $title -year $year -cleanVersion $cleanVersion -preferredUsernames $preferredUsernames
                $missing = @()

                if ($setInfo) {
                    # Season poster
                    if ("season" -in $mediuxFilters) {
                        $seasonPoster = $setInfo.seasonPosters | Where-Object { $_.season -eq $season } | Select-Object -First 1
                        if ($seasonPoster) {
                            $posterUrl = "https://api.mediux.pro/assets/$($seasonPoster.id)"
                            Upload-SeasonPoster `
                                -ratingKey $ratingKey `
                                -seasonNumber $season `
                                -posterUrl $posterUrl `
                                -plexToken $plexToken `
                                -plexHost $plexHost
                        } else {
                            $missing += "season"
                        }
                    }
                    # Title card
                    if ("titlecard" -in $mediuxFilters) {
                        $titleCard = $setInfo.titleCards | Where-Object { $_.season -eq $season -and $_.episode -eq $episode } | Select-Object -First 1
                        if ($titleCard) {
                            $posterUrl = "https://api.mediux.pro/assets/$($titleCard.id)"
                            Upload-TitleCard `
                                -showRatingKey $ratingKey `
                                -seasonNumber $season `
                                -episodeNumber $episode `
                                -posterUrl $posterUrl `
                                -plexToken $plexToken `
                                -plexHost $plexHost
                        } else {
                            $missing += "titlecard"
                        }
                    }
                } else {
                    # No set at all for this show
                    if ("season" -in $mediuxFilters)   { $missing += "season" }
                    if ("titlecard" -in $mediuxFilters){ $missing += "titlecard" }
                }

                if ($missing.Count -gt 0) {
                    Add-MissingPosterEntry `
                        -showTitle $title `
                        -ratingKey $ratingKey `
                        -season $season `
                        -episode $episode `
                        -tmdbId $tmdbId `
                        -setId ($setInfo ? $setInfo.setId : $null) `
                        -missingItems $missing
                }
            }
            # --- 2. Otherwise, run batch (recent episodes) logic---
            else {
                $episodesUrl = "$plexHost/library/metadata/$ratingKey/allLeaves?X-Plex-Token=$plexToken"
                $episodesMetadata = Invoke-RestMethod -Uri $episodesUrl -Method Get -ContentType "application/xml"
                $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                $recentEpisodes = @($episodesMetadata.MediaContainer.Video | Where-Object {
                    ($now - $_.addedAt) -lt 300
                })
                if ($recentEpisodes.Count -eq 0) {
                    Log-Message -Type "INF" -Message "No newly added episodes found. Skipping Mediux logic."
                    return
                }
                if ("season" -in $mediuxFilters -or "titlecard" -in $mediuxFilters) {
                    try {
                        $metadataUrl = "$plexHost/library/metadata/$ratingKey?X-Plex-Token=$plexToken"
                        $metaXml = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
                        $guid = $metaXml.MediaContainer.Directory.guid | Where-Object { $_.id -like "tmdb*" }
                        if (-not $tmdbId -and $guid -and ($guid.id -match "\d+")) {
                            $tmdbId = [int]($guid.id -replace "\D", "")
                        }
                        if (-not $tmdbId) {
                            Log-Message -Type "WRN" -Message "TMDB ID not found for show: $title"
                            return
                        }

                        $setInfo = Get-MediuxShowSets -tmdbId $tmdbId -title $title -year $year -cleanVersion $cleanVersion -preferredUsernames $preferredUsernames

                        foreach ($ep in $recentEpisodes) {
                            $season = $ep.parentIndex
                            $epNum = $ep.index
                            $missing = @()
                            $seasonPoster = $null
                            $titleCard = $null

                            if ($setInfo) {
                                if ("season" -in $mediuxFilters) {
                                    $seasonPoster = $setInfo.seasonPosters | Where-Object { $_.season -eq $season } | Select-Object -First 1
                                    if ($seasonPoster) {
                                        $posterUrl = "https://api.mediux.pro/assets/$($seasonPoster.id)"
                                        Upload-SeasonPoster `
                                            -ratingKey $ratingKey `
                                            -seasonNumber $season `
                                            -posterUrl $posterUrl `
                                            -plexToken $plexToken `
                                            -plexHost $plexHost
                                    } else {
                                        $missing += "season"
                                    }
                                }
                                if ("titlecard" -in $mediuxFilters) {
                                    $titleCard = $setInfo.titleCards | Where-Object { $_.season -eq $season -and $_.episode -eq $epNum } | Select-Object -First 1
                                    if ($titleCard) {
                                        $posterUrl = "https://api.mediux.pro/assets/$($titleCard.id)"
                                        Upload-TitleCard `
                                            -showRatingKey $ratingKey `
                                            -seasonNumber $season `
                                            -episodeNumber $epNum `
                                            -posterUrl $posterUrl `
                                            -plexToken $plexToken `
                                            -plexHost $plexHost
                                    } else {
                                        $missing += "titlecard"
                                    }
                                }
                            } else {
                                if ("season" -in $mediuxFilters)   { $missing += "season" }
                                if ("titlecard" -in $mediuxFilters){ $missing += "titlecard" }
                            }

                            if ($missing.Count -gt 0) {
                                Add-MissingPosterEntry `
                                    -showTitle $title `
                                    -ratingKey $ratingKey `
                                    -season $season `
                                    -episode $epNum `
                                    -tmdbId $tmdbId `
                                    -setId ($setInfo ? $setInfo.setId : $null) `
                                    -missingItems $missing
                            }
                        }
                    } catch {
                        Log-Message -Type "ERR" -Message "Failed to process Mediux posters for ${title}: $_"
                    }
                }
            }
        }
        elseif ($type -eq "movie") {
    try {
        $setInfo = Get-MediuxMovieSetId `
            -tmdbId $tmdbId `
            -preferredUsernames $preferredUsernames `
            -title $title `
            -year $year `
            -cleanVersion $cleanVersion

        if ($setInfo -and $setInfo.assetUrl) {
            $posterUrl = $setInfo.assetUrl
            Upload-Poster `
                -ratingKey $ratingKey `
                -posterUrl $posterUrl `
                -plexToken $plexToken `
                -plexHost $plexHost
        } else {
            Log-Message -Type "DBG" -Message "Calling Add-MissingPosterEntry with: type=$type, title=$title, ratingKey=$ratingKey, tmdbId=$tmdbId, setId=$($setInfo ? $setInfo.setId : $null), missing=poster"
            Add-MissingPosterEntry `
    -title $title `
    -ratingKey $ratingKey `
    -season $null `
    -episode $null `
    -tmdbId $tmdbId `
    -setId ($setInfo ? $setInfo.setId : $null) `
    -missingItems @("poster") `
    -year $year

        }
    } catch {
        Log-Message -Type "ERR" -Message "Failed to process Mediux poster for movie ${title}: $_"
    }
}

        else {
            Log-Message -Type "WRN" -Message "Unknown media type passed to Invoke-MediuxPosterSync: $mediaType"
        }
    } catch {
        Log-Message -Type "ERR" -Message "Failed to process $mediaType '$title': $_"
    }
}
