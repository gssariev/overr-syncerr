function Generate-UserSubtitlePreferences {
    $tokenFile = "/mnt/usr/user_tokens.json"
    $subtitlePrefFile = "/mnt/usr/user_subs_pref.json"

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

    # If subtitle preference file exists, load existing preferences
    if (Test-Path $subtitlePrefFile) {
        try {
            $existingPreferences = Get-Content -Path $subtitlePrefFile | ConvertFrom-Json -AsHashtable
            if ($existingPreferences -is [hashtable]) {
                $defaultPreferences = $existingPreferences
            }
        } catch {
            Log-Message -Type "ERR" -Message "Error reading subtitle preference file, resetting..."
            $defaultPreferences = @{}
        }
    }

    # Compare number of usernames in user_tokens.json and user_subs_pref.json
    $userTokenCount = $userTokens.Count
    $subtitlePrefCount = $defaultPreferences.Count

    if ($userTokenCount -ne $subtitlePrefCount) {
        foreach ($plexUsername in $userTokens.Keys) {
            if (-not $defaultPreferences.ContainsKey($plexUsername)) {
                # Assign a default preference with prioritized list
                $defaultPreferences[$plexUsername] = @{
                    "preferred" = @(
                        @{ "languageCode" = "eng"; "forced" = $true; "codec" = "srt" } # Prefer forced SRT subtitles
                        
                    );
                    "fallback" = @{ "forced" = $false; "codec" = "srt" } # Default fallback to non-forced SRT
                }
                Log-Message -Type "INF" -Message "Added default subtitle preference for user: $plexUsername"
            }
        }

        # Save updated preferences
        $defaultPreferences | ConvertTo-Json -Depth 10 | Set-Content -Path $subtitlePrefFile -Encoding utf8
        Log-Message -Type "SUC" -Message "User subtitle preferences updated and saved to $subtitlePrefFile"
    } else {
        Log-Message -Type "INF" -Message "User subtitle preferences are up to date. No changes needed."
    }
}