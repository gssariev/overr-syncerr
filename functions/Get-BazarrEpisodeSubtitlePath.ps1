function Get-BazarrEpisodeSubtitlePath {
    param ([string]$seriesId, [string]$episodeId, [string]$languageName, [bool]$hearingImpaired, [string]$bazarrApiKey, [string]$bazarrUrl)
    $url = "$bazarrUrl/episodes?seriesid%5B%5D=$seriesId&episodeid%5B%5D=$episodeId&apikey=$bazarrApiKey"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        foreach ($episode in $response.data) {
            foreach ($subtitle in $episode.subtitles) {
                if ($subtitle.name -eq $languageName -and $subtitle.hi -eq $hearingImpaired) {
                    return $subtitle.path
                }
            }
        }
        return $null
    } catch {
        return $null
    }
}