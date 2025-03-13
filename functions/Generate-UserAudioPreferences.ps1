function Generate-UserAudioPreferences {
    $tokenFile = "/mnt/usr/user_tokens.json"
    $audioPrefFile = "/mnt/usr/user_audio_pref.json"

    if (-not (Test-Path $tokenFile)) {
        Log-Message -Type "WRN" -Message "User token file not found: $tokenFile"
        return
    }

    try {
        $userTokens = Get-Content -Path $tokenFile | ConvertFrom-Json -AsHashtable
    } catch {
        Log-Message -Type "ERR" -Message "Error reading user token file: $_"
        return
    }

    $defaultPreferences = @{}

    # If audio preference file exists, load existing preferences
    if (Test-Path $audioPrefFile) {
        try {
            $existingPreferences = Get-Content -Path $audioPrefFile | ConvertFrom-Json -AsHashtable
            if ($existingPreferences -is [hashtable]) {
                $defaultPreferences = $existingPreferences
            }
        } catch {
            Log-Message -Type "ERR" -Message "Error reading audio preference file, resetting..."
            $defaultPreferences = @{}
        }
    }

    # Compare number of usernames in user_tokens.json and user_audio_pref.json
    $userTokenCount = $userTokens.Keys.Count
    $audioPrefCount = $defaultPreferences.Keys.Count

    if ($userTokenCount -ne $audioPrefCount) {
        foreach ($user in $userTokens.Keys) {
            $plexUsername = $user

            if (-not $defaultPreferences.ContainsKey($plexUsername)) {
                # Assign a default preference with prioritized list
                $defaultPreferences[$plexUsername] = @{
                    "preferred" = @(
                        @{ "languageCode" = "eng"; "codec" = "EAC3"; "channels" = 6 },
                        @{ "languageCode" = "eng"; "codec" = "AAC"; "channels" = 2 }
                    )
                    "fallback" = @{
                        "matchChannels" = $true
                    }
                }
                Log-Message -Type "INF" -Message "Added default audio preference for user: $plexUsername"
            }
        }

        # Save updated preferences
        $defaultPreferences | ConvertTo-Json -Depth 10 | Set-Content -Path $audioPrefFile
        Log-Message -Type "SUC" -Message "User audio preferences updated and saved to $audioPrefFile"
    } else {
        Log-Message -Type "INF" -Message "User audio preferences are up to date. No changes needed."
    }
}
