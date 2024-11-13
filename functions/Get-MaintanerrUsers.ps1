function Get-MaintanerrUsers {
    param (
        [string]$maintainerrUrl,
        [string]$maintainerrApiKey
    )

    $usersEndpoint = "$maintainerrUrl/api/plex/users"
    $headers = @{ 'X-Api-Key' = $maintainerrApiKey }
    $response = Invoke-RestMethod -Uri $usersEndpoint -Headers $headers -Method Get
    return $response
}
