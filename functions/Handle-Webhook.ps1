function Handle-Webhook {
    param ([string]$jsonPayload)

    $payload = $jsonPayload | ConvertFrom-Json -AsHashtable

    # Retrieve ADD_LABEL_KEYWORDS env var
    $addLabelKeywords = $env:ADD_LABEL_KEYWORDS | ConvertFrom-Json

    # Plex: Handle new episode
    if (
        $payload.ContainsKey('event') -and
        $payload["event"] -eq "library.new" -and
        $payload["Metadata"]["librarySectionType"] -eq "show" -and
        $payload["Metadata"]["type"] -eq "episode"
    ) {
        $ratingKey = $payload["Metadata"]["ratingKey"]
        $title = $payload["Metadata"]["grandparentTitle"]
        $season = $payload["Metadata"]["parentIndex"]
        $episode = $payload["Metadata"]["index"]
        $episodeTitle = $payload["Metadata"]["title"]

        Log-Message -Type "INF" -Message "📺 New episode added: $title - S$("{0:D2}" -f $season)E$("{0:D2}" -f $episode) \"$episodeTitle\""

        if ($enableAudioPref) {
            Set-AudioTrack -RatingKey $ratingKey
            Set-SubtitleTrack -RatingKey $ratingKey
        }

        return
    }

    # Plex: Handle new show (fetch recently added children episodes)
if (
    $payload.ContainsKey('event') -and
    $payload["event"] -eq "library.new" -and
    $payload["Metadata"]["librarySectionType"] -eq "show" -and
    $payload["Metadata"]["type"] -eq "show"
) {
    $showTitle = $payload["Metadata"]["title"]
    $showRatingKey = $payload["Metadata"]["ratingKey"]
    Log-Message -Type "INF" -Message "📚 New show added: $showTitle (RatingKey: $showRatingKey)"

    if ($enableAudioPref) {
        try {
            $episodesUrl = "$plexHost/library/metadata/$showRatingKey/allLeaves?X-Plex-Token=$plexToken"
            $episodesMetadata = Invoke-RestMethod -Uri $episodesUrl -Method Get -ContentType "application/xml"

            $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $thresholdSeconds = 300  # Only consider episodes added in the last 5 minutes

            $recentEpisodes = @($episodesMetadata.MediaContainer.Video | Where-Object {
                ($now - $_.addedAt) -lt $thresholdSeconds
            })

            if ($recentEpisodes.Count -eq 0) {
                Log-Message -Type "INF" -Message "No newly added episodes found in show. Skipping."
                return
            }

            foreach ($episode in $recentEpisodes) {
                $episodeTitle = $episode.title
                $season = $episode.parentIndex
                $epNum = $episode.index
                $epKey = $episode.ratingKey

                Log-Message -Type "INF" -Message "🎬 Processing: $showTitle S$("{0:D2}" -f $season)E$("{0:D2}" -f $epNum) - $episodeTitle"

                Set-AudioTrack -RatingKey $epKey
                Set-SubtitleTrack -RatingKey $epKey
            }

        } catch {
            Log-Message -Type "ERR" -Message "Failed to retrieve or process episodes for $showTitle. Error: $_"
        }
    }

    return
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
