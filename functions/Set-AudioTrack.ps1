function Set-AudioTrack {
    param ([string]$ratingKey)

    $tokenFile = "/mnt/usr/user_tokens.json"
    $audioPrefFile = "/mnt/usr/user_audio_pref.json"

    if (-not (Test-Path $tokenFile)) {
        Log-Message -Type "ERR" -Message "User token file not found: $tokenFile"
        return
    }

    if (-not (Test-Path $audioPrefFile)) {
        Log-Message -Type "ERR" -Message "Audio preference file not found: $audioPrefFile"
        return
    }

    try {
        $userTokens = Get-Content -Path $tokenFile | ConvertFrom-Json
        $userAudioPreferences = Get-Content -Path $audioPrefFile | ConvertFrom-Json
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
                Process-MediaItem -ratingKey $episode.ratingKey -userTokens $userTokens -userAudioPreferences $userAudioPreferences
            }
        }
        return
    }

    # If not a show, process it as a single media item
    Process-MediaItem -ratingKey $ratingKey -userTokens $userTokens -userAudioPreferences $userAudioPreferences
}

function Process-MediaItem {
    param (
        [string]$ratingKey,
        [PSCustomObject]$userTokens,
        [PSCustomObject]$userAudioPreferences
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
    $audioTracks = $part.Stream | Where-Object { $_.streamType -eq "2" }
    
    if (-not $audioTracks) {
        Log-Message -Type "ERR" -Message "No audio tracks found for media item $ratingKey"
        return
    }

    # Identify default track
    $defaultTrack = $audioTracks | Where-Object { $_.default -eq "1" }
    
    Log-Message -Type "INF" -Message "Available audio tracks: $($audioTracks | ForEach-Object { $_.extendedDisplayTitle })"
    
    # Cache already chosen tracks to minimize redundant operations
    $selectedTracksCache = @{}
    
    foreach ($user in $userTokens.PSObject.Properties) {
        $plexUsername = $user.Name
        $userToken = $user.Value

        if (-not $userAudioPreferences.PSObject.Properties[$plexUsername]) {
            Log-Message -Type "WRN" -Message "No audio track preference found for user: $plexUsername. Skipping."
            continue
        }

        $userPreferences = $userAudioPreferences.$plexUsername.preferred
        Log-Message -Type "INF" -Message "User '$plexUsername' prefers: $($userPreferences | ForEach-Object { "$($_.language) ($($_.codec) $($_.channels))" })"

        $selectedTrack = $null

        # Step 1: Exact Match (Language, Codec, Channels)
        foreach ($pref in $userPreferences) {
            $selectedTrack = $audioTracks | Where-Object {
                $_.languageTag -eq $pref.language -and $_.codec -eq $pref.codec -and $_.channels -eq $pref.channels
            }
            if ($selectedTrack) { break }
        }

        # Step 2: If no exact match, match language only
        if (-not $selectedTrack) {
            foreach ($pref in $userPreferences) {
                $selectedTrack = $audioTracks | Where-Object {
                    $_.languageTag -eq $pref.language
                } | Select-Object -First 1
                if ($selectedTrack) { break }
            }
        }

        # Step 3: Match by Channel Count if Language Not Found
        if (-not $selectedTrack) {
            foreach ($pref in $userPreferences) {
                $selectedTrack = $audioTracks | Where-Object {
                    $_.channels -eq $pref.channels
                } | Select-Object -First 1
                if ($selectedTrack) { break }
            }
        }

        # Step 4: Use default track if still no match
        if (-not $selectedTrack -and $defaultTrack) {
            $selectedTrack = $defaultTrack
        }

        if (-not $selectedTrack) {
            Log-Message -Type "WRN" -Message "No suitable track found for user '$plexUsername'. Skipping."
            continue
        }

        $audioStreamId = $selectedTrack.id
        $updateUrl = "$plexHost/library/parts/$partId"+"?X-Plex-Token=$userToken&audioStreamID=$audioStreamId"
        try {
            Invoke-RestMethod -Uri $updateUrl -Method Put
         Log-Message -Type "SUC" -Message "Successfully set audio track for user '$plexUsername': $($selectedTrack.extendedDisplayTitle)"
        } catch {
            Log-Message -Type "ERR" -Message "Error setting audio track for user '$plexUsername'. Status: $($_.Exception.Response.StatusCode) - $($_.Exception.Message)"
        }
    }
}
