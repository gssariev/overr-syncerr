function Check-MaintanerrMediaSeen {
    param (
        [int]$plexId,
        [int]$userId,
        [string]$maintainerrUrl,
        [string]$maintainerrApiKey
    )

    $seenEndpoint = "$maintainerrUrl/api/plex/meta/$plexId/seen"
    $headers = @{ 'X-Api-Key' = $maintainerrApiKey }
    $response = Invoke-RestMethod -Uri $seenEndpoint -Headers $headers -Method Get
    return $response | Where-Object { $_.accountID -eq $userId }
}
