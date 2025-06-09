function Get-PlexUserTokens {
    param (
        [string]$plexToken,
        [string]$plexClientId
    )

    $tokenFile = "/mnt/usr/user_tokens.json"
    $plexUsersUrl = "https://plex.tv/api/servers/$plexClientId/shared_servers?X-Plex-Token=$plexToken"
    $homeUsersUrl = "https://plex.tv/api/v2/home/users?X-Plex-Client-Identifier=$plexClientId&X-Plex-Token=$plexToken"

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
        # Fetch managed accounts (with potentially missing usernames)
        $homeUsersResponse = Invoke-RestMethod -Uri $homeUsersUrl -Method Get -Headers @{
            "Accept" = "application/xml"
        }
        $homeUsersXml = [xml]$homeUsersResponse.OuterXml

        # Get the first user (admin account)
        $adminUser = $homeUsersXml.home.users.user[0]
        if ($adminUser) {
            $adminUsername = $adminUser.username
            if ($adminUsername) {
                # Add the admin user and token
                $existingUserTokens[$adminUsername] = $plexToken
                Log-Message -Type "SUC" -Message "Added admin token for user: $adminUsername"
            }
        }

        # Fetch shared users from Plex API
        $response = Invoke-RestMethod -Uri $plexUsersUrl -Method Get -Headers @{
            "Accept" = "application/xml"
        }
        $xmlResponse = [xml]$response.OuterXml
        $sharedServers = $xmlResponse.MediaContainer.SharedServer

        # Create a hashtable to store tokens
        $userTokens = @{}

        foreach ($server in $sharedServers) {
            $plexUsername = $server.username
            $userAuthToken = $server.accessToken
            $userId = $server.userID

            # Handle blank username (managed accounts)
            if (-not $plexUsername -and $userId) {
                $managedUser = $homeUsersXml.home.users.user | Where-Object { $_.id -eq $userId }
                if ($managedUser) {
                    $plexUsername = $managedUser.title
                }
            }

            if ($userAuthToken) {
                $userTokens[$plexUsername] = $userAuthToken
                Log-Message -Type "SUC" -Message "Retrieved token for user: $plexUsername"
            } else {
                Log-Message -Type "WRN" -Message "No token found for user: $plexUsername"
            }
        }

        # Merge admin token and shared tokens
        $updatedTokens = @{}
        foreach ($key in $existingUserTokens.Keys) {
            $updatedTokens[$key] = $existingUserTokens[$key]
        }
        foreach ($key in $userTokens.Keys) {
            $updatedTokens[$key] = $userTokens[$key]
        }

        # Update the JSON file if the count has changed
        $newUserCount = $updatedTokens.Keys.Count
        $existingUserCount = $existingUserTokens.Keys.Count

        if ($newUserCount -ne $existingUserCount) {
            $updatedTokens | ConvertTo-Json -Depth 10 | Set-Content -Path $tokenFile
            Log-Message -Type "WRN" -Message "User count changed ($existingUserCount → $newUserCount). Updated user tokens in $tokenFile"
        } else {
            Log-Message -Type "INF" -Message "No change in user count ($existingUserCount users). Skipping update."
        }
    } catch {
        Log-Message -Type "ERR" -Message "Error retrieving Plex user tokens: $($_.Exception.Message)"
    }
}
