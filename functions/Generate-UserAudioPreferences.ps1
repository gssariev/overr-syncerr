function Generate-UserAudioPreferences {
    $tokenFile = "/mnt/usr/user_tokens.json"
    $audioPrefFile = "/mnt/usr/user_audio_pref.json"

    if (-not (Test-Path $tokenFile)) {
        Log-Message -Type "WRN" -Message "User token file not found: $tokenFile"
        return
    }

    try {
        $userTokens = Get-Content -Path $tokenFile | ConvertFrom-Json
    } catch {
        Log-Message -Type "ERR" -Message "Error reading user token file: $_"
        return
    }

    $defaultPreferences = @{}

    # If audio preference file exists, load existing preferences
    if (Test-Path $audioPrefFile) {
        try {
            $defaultPreferences = Get-Content -Path $audioPrefFile | ConvertFrom-Json
        } catch {
            Log-Message -Type "ERR" -Message "Error reading audio preference file, resetting..."
            $defaultPreferences = @{}
        }
    }

    # Ensure each user has an entry in user_audio_pref.json
    foreach ($user in $userTokens.PSObject.Properties) {
        $plexUsername = $user.Name

        if (-not $defaultPreferences.PSObject.Properties[$plexUsername]) {
            # Assign a default preference with prioritized list
            $defaultPreferences[$plexUsername] = @{
                "preferred" = @(
                    @{ "language" = "English"; "codec" = "EAC3"; "channels" = 6 },
                    @{ "language" = "English"; "codec" = "AAC"; "channels" = 2 }
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
    Log-Message -Type "SUC" -Message "User audio preferences saved to $audioPrefFile"
}
