function Get-OverseerrUserId {
    param (
        [string]$overseerrUrl,
        [string]$overseerrApiKey,
        [string]$plexUsername
    )

    $url = "$overseerrUrl/user?take=100"  # Adjust `take` if necessary to retrieve all users
    $headers = @{ "X-Api-Key" = $overseerrApiKey }

    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        $user = $response.results | Where-Object { $_.plexUsername -eq $plexUsername }
        return $user.id
    } catch {
        Write-Host "Failed to retrieve user ID from Overseerr for plexUsername: $plexUsername. Error: $_"
    }
}