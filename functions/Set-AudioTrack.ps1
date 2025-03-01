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

    # Validate metadata structure
    if (-not $metadata.MediaContainer.Video) {
        Log-Message -Type "ERR" -Message "No video metadata found for ratingKey: $ratingKey"
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

        # Check if we've already selected an optimal track for this media
        if ($selectedTracksCache.ContainsKey($plexUsername)) {
            $selectedTrack = $selectedTracksCache[$plexUsername]
        } else {
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
                Log-Message -Type "WRN" -Message "No preferred track found for '$plexUsername'. Falling back to default track: $($defaultTrack.extendedDisplayTitle)"
                $selectedTrack = $defaultTrack
            }

            if (-not $selectedTrack) {
                Log-Message -Type "WRN" -Message "No suitable track found for user '$plexUsername'. Skipping."
                continue
            }

            # Cache the selected track to avoid redundant searches
            $selectedTracksCache[$plexUsername] = $selectedTrack
        }

        $audioStreamId = $selectedTrack.id
        Log-Message -Type "INF" -Message "Setting audio track: $($selectedTrack.extendedDisplayTitle) (ID: $audioStreamId) for user: $plexUsername"

        # Apply the preferred audio track
        $updateUrl = "$plexHost/library/parts/$partId"+"?X-Plex-Token=$userToken&audioStreamID=$audioStreamId"
        try {
            Invoke-RestMethod -Uri $updateUrl -Method Put
            Log-Message -Type "SUC" -Message "Successfully set audio track for user '$plexUsername'."
        } catch {
            Log-Message -Type "ERR" -Message "Error setting audio track for user '$plexUsername'. Status: $($_.Exception.Response.StatusCode) - $($_.Exception.Message)"
        }
    }
}
