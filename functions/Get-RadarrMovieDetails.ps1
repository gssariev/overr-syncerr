function Get-RadarrMovieDetails {
    param ([string]$tmdbId, [string]$radarrApiKey, [string]$radarrUrl)
    $url = "$radarrUrl/movie?tmdbId=$tmdbId&apikey=$radarrApiKey"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        return $response
    } catch {
        return $null
    }
}