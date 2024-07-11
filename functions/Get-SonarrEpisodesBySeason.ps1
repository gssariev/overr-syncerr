function Get-SonarrEpisodesBySeason {
    param ([string]$seriesId, [int]$seasonNumber, [string]$sonarrApiKey, [string]$sonarrUrl)
    $url = "$sonarrUrl/episode?seriesId=$seriesId&seasonNumber=$seasonNumber&includeImages=false&apikey=$sonarrApiKey"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        return $response
    } catch {
        return $null
    }
}