function Set-OverseerrUserLimits {
    param (
        [string]$username,
        [string]$overseerrUrl,
        [string]$overseerrApiKey,
        [int]$movieQuotaLimit,
        [int]$movieQuotaDays,
		[int]$tvQuotaLimit,
		[int]$tvQuotaDays
    )

    $userEndpoint = "$overseerrUrl/user"
    $headers = @{ 'X-Api-Key' = $overseerrApiKey }
    $response = Invoke-RestMethod -Uri $userEndpoint -Headers $headers -Method Get
    $user = $response.results | Where-Object { $_.plexUsername -eq $username }

    if ($user) {
        $updateEndpoint = "$overseerrUrl/user/$($user.id)/settings/main"
        $payload = @{
            movieQuotaLimit = $movieQuotaLimit
            movieQuotaDays = $movieQuotaDays
			tvQuotaLimit = $tvQuotaLimit
			tvQuotaDays = $tvQuotaDays
        }
        $payloadJson = $payload | ConvertTo-Json -Depth 3
        Invoke-RestMethod -Uri $updateEndpoint -Headers $headers -Method Post -Body $payloadJson -ContentType 'application/json'
        Write-Host "Set Overseerr limits for ${username}: $movieQuotaLimit movies every $movieQuotaDays days"
    } else {
        Write-Host "User $username not found in Overseerr."
    }
}
