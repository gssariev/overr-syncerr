function Handle-SubtitlesIssue {
    param ([psobject]$payload)

    Write-Host "Subtitle issue detected"

    $is4K = $payload.message -match "(?i)4K"
    $isHI = $payload.message -match "(?i)hi"
    $containsSyncKeyword = Contains-SyncKeyword -issueMessage $payload.message -syncKeywords $syncKeywords
    if (-not $containsSyncKeyword) {
        Write-Host "Issue message does not contain sync keywords, skipping."
        return
    }

    $bazarrApiKey = if ($is4K) { $bazarr4kApiKey } else { $bazarrApiKey }
    $bazarrUrl = if ($is4K) { $bazarr4kUrl } else { $bazarrUrl }
    $radarrApiKey = if ($is4K) { $radarr4kApiKey } else { $radarrApiKey }
    $radarrUrl = if ($is4K) { $radarr4kUrl } else { $radarrUrl }
    $sonarrApiKey = if ($is4K) { $sonarr4kApiKey } else { $sonarrApiKey }
    $sonarrUrl = if ($is4K) { $sonarr4kUrl } else { $sonarrUrl }

    Write-Host "Using bazarrUrl: $bazarrUrl"

    if ($payload.media.media_type -eq "movie") {
        $tmdbId = $payload.media.tmdbId
        Write-Host "Fetching movie details from Radarr for tmdbId: $tmdbId"

        try {
            $radarrMovieDetails = Get-RadarrMovieDetails -tmdbId $tmdbId -radarrApiKey $radarrApiKey -radarrUrl $radarrUrl
        } catch {
            Write-Host "Failed to get movie details from Radarr: $_"
            return
        }

        if ($radarrMovieDetails) {
            $movieId = $radarrMovieDetails.id
            $radarrId = $movieId
            Write-Host "Movie ID: $movieId, Radarr ID: $radarrId"

            $languageName = Map-LanguageCode -issueMessage $payload.message -languageMap $languageMap
            Write-Host "Mapped Language Name: $languageName"

            $newSubtitlePath = Get-BazarrMovieSubtitlePath -radarrId $radarrId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
            Write-Host "Subtitle Path: $newSubtitlePath"

            if ($newSubtitlePath) {
                $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                Write-Host "Extracted Language Code: $languageCode"
                
                $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=movie&id=$movieId&reference=(a%3A0)&apikey=$bazarrApiKey"
                Write-Host "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"

                try {
                    $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                    Write-Host "Bazarr response: Synced"

                    Post-OverseerrComment -issueId $payload.issue.issue_id -message "Subtitles have been synced" -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                    Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                } catch {
                    Write-Host "Failed to send PATCH request to Bazarr: $_"
                }
            } else {
                Write-Host "Subtitle path not found in Bazarr"
            }
        } else {
            Write-Host "Movie details not found in Radarr"
        }
    } elseif ($payload.media.media_type -eq "tv") {
        $tvdbId = $payload.media.tvdbId
        $affectedSeason = $payload.extra | Where-Object { $_.name -eq "Affected Season" } | Select-Object -ExpandProperty value
        $affectedEpisode = $payload.extra | Where-Object { $_.name -eq "Affected Episode" } | Select-Object -ExpandProperty value
        Write-Host "Fetching seriesId from Sonarr for tvdbId: $tvdbId"

        $seriesId = Get-SonarrSeriesId -tvdbId $tvdbId -sonarrApiKey $sonarrApiKey -sonarrUrl $sonarrUrl
        if ($seriesId) {
            Write-Host "Series ID: $seriesId"

            if ($affectedEpisode) {
                Write-Host "Fetching episode details from Sonarr for seriesId: $seriesId, season: $affectedSeason, episode: $affectedEpisode"
                $episodeDetails = Get-SonarrEpisodeDetails -seriesId $seriesId -seasonNumber ([int]$affectedSeason) -episodeNumber ([int]$affectedEpisode) -sonarrApiKey $sonarrApiKey -sonarrUrl $sonarrUrl
                if ($episodeDetails) {
                    $episodeId = $episodeDetails.id
                    $episodeFileId = $episodeDetails.episodeFileId
                    Write-Host "Episode ID: $episodeId, Episode File ID: $episodeFileId"

                    $languageName = Map-LanguageCode -issueMessage $payload.message -languageMap $languageMap
                    Write-Host "Mapped Language Name: $languageName"

                    $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                    Write-Host "Subtitle Path: $newSubtitlePath"

                    if ($newSubtitlePath) {
                        $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                        Write-Host "Extracted Language Code: $languageCode"
                        
                        $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                        $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&apikey=$bazarrApiKey"
                        Write-Host "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"

                        try {
                            $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                            Write-Host "Bazarr response: Synced"

                            Post-OverseerrComment -issueId $payload.issue.issue_id -message "Subtitles have been synced" -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                            Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        } catch {
                            Write-Host "Failed to send PATCH request to Bazarr: $_"
                        }
                    } else {
                        Write-Host "Subtitle path not found in Bazarr"
                    }
                } else {
                    Write-Host "Episode details not found in Sonarr"
                }
            } else {
                Write-Host "Affected Episode missing, fetching all episodes for season: $affectedSeason"
                $episodes = Get-SonarrEpisodesBySeason -seriesId $seriesId -seasonNumber ([int]$affectedSeason) -sonarrApiKey $sonarrApiKey -sonarrUrl $sonarrUrl
                if ($episodes) {
                    $languageName = Map-LanguageCode -issueMessage $payload.message -languageMap $languageMap
                    Write-Host "Mapped Language Name: $languageName"

                    $allSubtitlesSynced = $true
                    foreach ($episode in $episodes) {
                        $episodeId = $episode.id
                        Write-Host "Processing episode ID: $episodeId"

                        $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                        Write-Host "Subtitle Path: $newSubtitlePath"

                        if ($newSubtitlePath) {
                            $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                            Write-Host "Extracted Language Code: $languageCode"
                            
                            $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                            $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&apikey=$bazarrApiKey"
                            Write-Host "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"

                            try {
                                $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                                Write-Host "Bazarr response: Synced"
                            } catch {
                                Write-Host "Failed to send PATCH request to Bazarr: $_"
                                $allSubtitlesSynced = $false
                            }
                        } else {
                            Write-Host "Subtitle path not found in Bazarr for episode ID: $episodeId"
                            $allSubtitlesSynced = $false
                        }
                    }
                    if ($allSubtitlesSynced) {
                        Post-OverseerrComment -issueId $payload.issue.issue_id -message "All subtitles have been synced" -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                    } else {
                        Write-Host "Not all subtitles were synced successfully"
                    }
                } else {
                    Write-Host "No episodes found for season: $affectedSeason"
                }
            }
        } else {
            Write-Host "Series ID not found in Sonarr"
        }
    } else {
        Write-Host "Unsupported media type: $($payload.media.media_type)"
    }
}