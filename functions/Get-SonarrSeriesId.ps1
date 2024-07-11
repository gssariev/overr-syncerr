function Get-SonarrSeriesId {
    param ([string]$tvdbId, [string]$sonarrApiKey, [string]$sonarrUrl)
    $url = "$sonarrUrl/series?tvdbId=$tvdbId&includeSeasonImages=false&apikey=$sonarrApiKey"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        return $response.id
    } catch {
        return $null
    }
}