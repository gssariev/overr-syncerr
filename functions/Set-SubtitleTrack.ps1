function Set-SubtitleTrack {
    param ([string]$ratingKey)

    $tokenFile = "/mnt/usr/user_tokens.json"
    $subtitlePrefFile = "/mnt/usr/user_subs_pref.json"

    if (-not (Test-Path $tokenFile)) {
        Log-Message -Type "ERR" -Message "User token file not found: $tokenFile"
        return
    }

    if (-not (Test-Path $subtitlePrefFile)) {
        Log-Message -Type "ERR" -Message "Subtitle preference file not found: $subtitlePrefFile"
        return
    }

    try {
        $userTokens = Get-Content -Path $tokenFile | ConvertFrom-Json
        $userSubtitlePreferences = Get-Content -Path $subtitlePrefFile | ConvertFrom-Json
    } catch {
        Log-Message -Type "ERR" -Message "Error reading configuration files: $_"
        return
    }

    # Fetch media metadata
    $metadataUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken"
    try {
        $metadata = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
    } catch {
        Log-Message -Type "ERR" -Message "Error retrieving metadata. Status: $($_.Exception.Response.StatusCode) - $($_.Exception.Message)"
        return
    }

    # Determine if this is a TV Show
    $isShow = $false
    if ($metadata.MediaContainer.Directory.type -eq "show") {
        $isShow = $true
        Log-Message -Type "INF" -Message "Detected TV Show: $($metadata.MediaContainer.Directory.title)"

        # Fetch seasons
        $seasonsUrl = "$plexHost/library/metadata/$ratingKey/children"+"?X-Plex-Token=$plexToken"
        try {
            $seasonsMetadata = Invoke-RestMethod -Uri $seasonsUrl -Method Get -ContentType "application/xml"
        } catch {
            Log-Message -Type "ERR" -Message "Error retrieving seasons. Status: $($_.Exception.Response.StatusCode) - $($_.Exception.Message)"
            return
        }

        # Loop through seasons
        foreach ($season in $seasonsMetadata.MediaContainer.Directory) {
            $seasonKey = $season.ratingKey
            Log-Message -Type "INF" -Message "Processing Season: $($season.title) (RatingKey: $seasonKey)"

            # Fetch episodes for the season
            $episodesUrl = "$plexHost/library/metadata/$seasonKey/children"+"?X-Plex-Token=$plexToken"
            try {
                $episodesMetadata = Invoke-RestMethod -Uri $episodesUrl -Method Get -ContentType "application/xml"
            } catch {
                Log-Message -Type "ERR" -Message "Error retrieving episodes for Season $($season.index). Status: $($_.Exception.Response.StatusCode) - $($_.Exception.Message)"
                continue
            }

            # Loop through episodes
            foreach ($episode in $episodesMetadata.MediaContainer.Video) {
                Log-Message -Type "INF" -Message "Processing Episode: $($episode.title) (S$($episode.parentIndex)E$($episode.index))"
                Process-SubtitleTrack -ratingKey $episode.ratingKey -userTokens $userTokens -userSubtitlePreferences $userSubtitlePreferences
            }
        }
        return
    }

    # If not a show, process it as a single media item
    Process-SubtitleTrack -ratingKey $ratingKey -userTokens $userTokens -userSubtitlePreferences $userSubtitlePreferences
}

function Process-SubtitleTrack {
    param (
        [string]$ratingKey,
        [PSCustomObject]$userTokens,
        [PSCustomObject]$userSubtitlePreferences
    )

    # Fetch media metadata
    $metadataUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken"
    try {
        $metadata = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
    } catch {
        Log-Message -Type "ERR" -Message "Error retrieving metadata for media item $ratingKey. Status: $($_.Exception.Response.StatusCode) - $($_.Exception.Message)"
        return
    }

    $video = $metadata.MediaContainer.Video
    if ($video -is [System.Array]) { $video = $video[0] }

    if (-not $video.Media) {
        Log-Message -Type "ERR" -Message "No media information found for ratingKey: $ratingKey"
        return
    }

    $part = $video.Media.Part
    if ($part -is [System.Array]) { $part = $part[0] }

    if (-not $part) {
        Log-Message -Type "ERR" -Message "No media part found for ratingKey: $ratingKey"
        return
    }

    $partId = $part.id
    $subtitleTracks = $part.Stream | Where-Object { $_.streamType -eq "3" }

    if (-not $subtitleTracks) {
        Log-Message -Type "WRN" -Message "No subtitles found for media item $ratingKey"
        return
    }

    Log-Message -Type "INF" -Message "Available subtitle tracks: $($subtitleTracks | ForEach-Object { $_.extendedDisplayTitle })"

    foreach ($user in $userTokens.PSObject.Properties) {
        $plexUsername = $user.Name
        $userToken = $user.Value

        if (-not $userSubtitlePreferences.PSObject.Properties[$plexUsername]) {
            Log-Message -Type "WRN" -Message "No subtitle preference found for user: $plexUsername. Skipping."
            continue
        }

        $userPreferences = $userSubtitlePreferences.$plexUsername.preferred
        Log-Message -Type "INF" -Message "User '$plexUsername' prefers: $($userPreferences | ForEach-Object { "$($_.languageCode) ($($_.codec)) Forced: $($_.forced)" })"

        $selectedTrack = $null

        # Step 1: Exact Match (LanguageCode, Codec, Forced)
        foreach ($pref in $userPreferences) {
            $selectedTrack = $subtitleTracks | Where-Object {
                $_.languageCode -eq $pref.languageCode -and
                $_.codec -eq $pref.codec -and
                (([bool]$_.forced -or $false) -eq $pref.forced)
            } | Select-Object -First 1
            if ($selectedTrack) { break }
        }

        # Step 2: LanguageCode + Codec Match (Ignore Forced Flag)
        if (-not $selectedTrack) {
            foreach ($pref in $userPreferences) {
                $selectedTrack = $subtitleTracks | Where-Object {
                    $_.languageCode -eq $pref.languageCode -and
                    $_.codec -eq $pref.codec
                } | Select-Object -First 1
                if ($selectedTrack) { break }
            }
        }

        # Step 3: Apply Fallback (if defined)
        if (-not $selectedTrack -and $userSubtitlePreferences.$plexUsername.fallback) {
            $fallbackPref = $userSubtitlePreferences.$plexUsername.fallback
            Log-Message -Type "INF" -Message "Applying fallback for user '$plexUsername': Codec=$($fallbackPref.codec), Forced=$($fallbackPref.forced)"

            $selectedTrack = $subtitleTracks | Where-Object {
                $_.codec -eq $fallbackPref.codec -and
                (([bool]$_.forced -or $false) -eq $fallbackPref.forced)
            } | Select-Object -First 1
        }

        # Step 4: Skip Subtitle Selection If No Match Found
        if (-not $selectedTrack) {
            Log-Message -Type "WRN" -Message "No suitable subtitle track found for user '$plexUsername'. Skipping subtitle selection."
            continue
        }

        # Step 5: Set Subtitle Track
        $subtitleStreamId = $selectedTrack.id
        $updateUrl = "$plexHost/library/parts/$partId"+"?X-Plex-Token=$userToken&subtitleStreamID=$subtitleStreamId"

        try {
            Invoke-RestMethod -Uri $updateUrl -Method Put
            Log-Message -Type "SUC" -Message "Successfully set subtitle track for user '$plexUsername': $($selectedTrack.extendedDisplayTitle)"
        } catch {
            Log-Message -Type "ERR" -Message "Error setting subtitle track for user '$plexUsername'. Status: $($_.Exception.Response.StatusCode) - $($_.Exception.Message)"
        }
    }
}
