function Handle-Webhook {
    param ([string]$jsonPayload)

    $payload = $jsonPayload | ConvertFrom-Json -AsHashtable
    $addLabelKeywords = $env:ADD_LABEL_KEYWORDS | ConvertFrom-Json

    $event = $payload["event"]
    $meta = $null
    if ($payload.ContainsKey("Metadata")) {
        $meta = $payload["Metadata"]
    }

    # Plex: Handle new library item from TV section
    if (
        $payload.ContainsKey('event') -and
        $event -eq "library.new" -and
        $meta -ne $null -and
        $meta["librarySectionType"] -eq "show"
    ) {
        if ($meta["type"] -eq "episode") {
            $episodeRatingKey = $meta["ratingKey"]
            $showRatingKey = $meta["grandparentRatingKey"]
            $title = $meta["grandparentTitle"]
            $season = $meta["parentIndex"]
            $episode = $meta["index"]
            $episodeTitle = $meta["title"]

            Log-Message -Type "INF" -Message "📺 New episode added: $title - S$("{0:D2}" -f $season)E$("{0:D2}" -f $episode) \"$episodeTitle\""

            if ($enableAudioPref) {
                Set-AudioTrack -RatingKey $episodeRatingKey
                Set-SubtitleTrack -RatingKey $episodeRatingKey
            }

            if ($enableMediux -and $episodeRatingKey) {
                try {
                    # Fetch TMDB ID from the show
                    $metadataUrl = "$plexHost/library/metadata/$showRatingKey"+"?X-Plex-Token=$plexToken"
                    $metaXml = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
                    $guid = $metaXml.MediaContainer.Directory.guid | Where-Object { $_.id -like "tmdb*" }

                    if (-not $guid -or -not ($guid.id -match "\d+")) {
                        Log-Message -Type "WRN" -Message "TMDB ID not found for show: $title"
                        return
                    }

                    $tmdbId = [int]($guid.id -replace "\D", "")

                    Invoke-MediuxPosterSync `
                        -title $title `
                        -ratingKey $showRatingKey `
                        -mediaType "show" `
                        -season $season `
                        -episode $episode `
                        -tmdbId $tmdbId
                } catch {
                    Log-Message -Type "ERR" -Message "Failed to fetch TMDB ID for show '$title': $_"
                }
            }

        } elseif ($meta["type"] -eq "show") {
            $title = $meta["title"]
            $ratingKey = $meta["ratingKey"]

            Log-Message -Type "INF" -Message "📚 New show added: $title (RatingKey: $ratingKey)"

            if ($enableAudioPref -or $enableMediux) {
                try {
                    $episodesUrl = "$plexHost/library/metadata/$ratingKey/allLeaves?X-Plex-Token=$plexToken"
                    $episodesXml = Invoke-RestMethod -Uri $episodesUrl -Method Get -ContentType "application/xml"

                    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                    $recentEpisodes = @($episodesXml.MediaContainer.Video | Where-Object {
                        ($now - $_.addedAt) -lt 300
                    })

                    if ($recentEpisodes.Count -eq 0) {
                        Log-Message -Type "INF" -Message "No newly added episodes found. Skipping."
                        return
                    }

                    # Retrieve TMDB ID from the show (not episodes)
                    $metadataUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken"
                    $metaXml = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
                    $guid = $metaXml.MediaContainer.Directory.guid | Where-Object { $_.id -like "tmdb*" }

                    if (-not $guid -or -not ($guid.id -match "\d+")) {
                        Log-Message -Type "WRN" -Message "TMDB ID not found for show: $title"
                        return
                    }

                    $tmdbId = [int]($guid.id -replace "\D", "")

                    foreach ($ep in $recentEpisodes) {
                        $season = $ep.parentIndex
                        $episode = $ep.index
                        $epRatingKey = $ep.ratingKey
                        $epTitle = $ep.title

                        Log-Message -Type "INF" -Message "🎬 Processing: $title S$("{0:D2}" -f $season)E$("{0:D2}" -f $episode) - $epTitle"

                        if ($enableAudioPref) {
                            Set-AudioTrack -RatingKey $epRatingKey
                            Set-SubtitleTrack -RatingKey $epRatingKey
                        }

                        if ($enableMediux) {
                            Invoke-MediuxPosterSync `
                                -title $title `
                                -ratingKey $ratingKey `
                                -mediaType "show" `
                                -season $season `
                                -episode $episode `
                                -tmdbId $tmdbId
                        }
                    }
                } catch {
                    Log-Message -Type "ERR" -Message "Failed to fetch or process episodes for show '$title': $_"
                }
            }
        }
    }

    # Overseerr MEDIA_AVAILABLE
    if ($payload["notification_type"] -eq "MEDIA_AVAILABLE") {
        Handle-MediaAvailable -payload $payload

        if ($enableKometa) {
            Trigger-Kometa
        }

    } elseif ($payload.ContainsKey("issue") -and $payload["issue"]["issue_type"] -eq "SUBTITLES") {
        Handle-SubtitlesIssue -payload $payload

    } elseif ($payload.ContainsKey("issue") -and $payload["issue"]["issue_type"] -eq "OTHER") {
        $message = $payload["message"].ToLower().Trim()
        $matchFound = $false

        foreach ($keyword in $addLabelKeywords) {
            if ($message -match [regex]::Escape($keyword.Trim())) {
                $matchFound = $true
                break
            }
        }

        if ($matchFound) {
            Handle-OtherIssue -payload $payload
        } else {
            Log-Message -Type "WRN" -Message "Received issue is not handled."
        }

    } elseif ($payload.ContainsKey("series") -and $payload.ContainsKey("eventType")) {
        switch ($payload["eventType"]) {
            "Download" {
                Handle-SonarrEpisodeFileAdded -payload $payload
            }
            default {
                Log-Message -Type "INF" -Message "Unhandled Sonarr event type: $($payload["eventType"])"
            }
        }
    }
}
