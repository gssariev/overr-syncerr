function Get-MaintainerrRequester {
    param (
        [int]$tmdbId,
        [string]$overseerrUrl,
        [string]$overseerrApiKey,
        [string]$type  # "movie" or "show"
    )

    $endpoint = "$overseerrUrl/api/overseerr/$type/$tmdbId"
    $headers = @{ 'X-Api-Key' = $overseerrApiKey }

    try {
        $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Get
        return $response.requestedBy.plexUsername
    } catch {
        Write-Host "Failed to retrieve requester information for TMDB ID: $tmdbId, Type: $type"
        return $null
    }
}