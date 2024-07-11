function Get-SonarrEpisodeDetails {
    param ([string]$seriesId, [int]$seasonNumber, [int]$episodeNumber, [string]$sonarrApiKey, [string]$sonarrUrl)
    $url = "$sonarrUrl/episode?seriesId=$seriesId&seasonNumber=$seasonNumber&includeImages=false&apikey=$sonarrApiKey"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        foreach ($episode in $response) {
            if ($episode.seasonNumber -eq $seasonNumber -and $episode.episodeNumber -eq $episodeNumber) {
                return $episode
            }
        }
        return $null
    } catch {
        return $null
    }
}