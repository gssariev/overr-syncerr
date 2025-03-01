function Get-PlexUserTokens {
    param (
        [string]$plexToken,
        [string]$plexClientId
    )

    $tokenFile = "/mnt/usr/user_tokens.json"
    $plexUsersUrl = "https://plex.tv/api/servers/$plexClientId/shared_servers"+"?X-Plex-Token=$plexToken"

    # Load existing user token data
    if (Test-Path $tokenFile) {
        try {
            $existingUserTokens = Get-Content -Raw -Path $tokenFile | ConvertFrom-Json -AsHashtable
        } catch {
            Log-Message -Type "ERR" -Message "Error reading user_tokens.json. Resetting..."
            $existingUserTokens = @{}
        }
    } else {
        $existingUserTokens = @{}
    }

    try {
        # Fetch shared users from Plex API
        $response = Invoke-RestMethod -Uri $plexUsersUrl -Method Get -Headers @{
            "Accept" = "application/xml"
        }

        # Convert XML response into a readable format
        $xmlResponse = [xml]$response.OuterXml
        $sharedServers = $xmlResponse.MediaContainer.SharedServer

        $userTokens = @{}

        foreach ($server in $sharedServers) {
            $plexUsername = $server.username
            $userAuthToken = $server.accessToken

            if ($userAuthToken) {
                $userTokens[$plexUsername] = $userAuthToken
                Log-Message -Type "SUC" -Message "Retrieved token for user: $plexUsername"
            } else {
                Log-Message -Type "WRN" -Message "No token found for user: $plexUsername"
            }
        }

        # Step 1: Compare new and existing user counts
        $newUserCount = $userTokens.Keys.Count
        $existingUserCount = $existingUserTokens.Keys.Count

        if ($newUserCount -ne $existingUserCount) {
            # Step 2: Update the JSON file if the count has changed
            $userTokens | ConvertTo-Json -Depth 10 | Set-Content -Path $tokenFile
            Log-Message -Type "WRN" -Message "User count changed ($existingUserCount → $newUserCount). Updated user tokens in $tokenFile"
        } else {
            Log-Message -Type "INF" -Message "No change in user count ($existingUserCount users). Skipping update."
        }
    } catch {
        Log-Message -Type "ERR" -Message "Error retrieving Plex user tokens: $($_.Exception.Message)"
    }
}
