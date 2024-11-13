function Get-BazarrEpisodeSubtitlePath {
    param ([string]$seriesId, [string]$episodeId, [string]$languageName, [bool]$hearingImpaired, [string]$bazarrApiKey, [string]$bazarrUrl)
    
    $url = "$bazarrUrl/episodes?seriesid%5B%5D=$seriesId&episodeid%5B%5D=$episodeId&apikey=$bazarrApiKey"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get

        # Try to find hearing-impaired subtitles first (if $hearingImpaired is true)
        if ($hearingImpaired) {
            foreach ($episode in $response.data) {
                foreach ($subtitle in $episode.subtitles) {
                    if ($subtitle.name -eq $languageName -and $subtitle.hi -eq $true) {
                        return $subtitle.path
                    }
                }
            }
        }

        # If no 'hi' subtitles are found or if $hearingImpaired is false, try to get non-hi subtitles
        foreach ($episode in $response.data) {
            foreach ($subtitle in $episode.subtitles) {
                if ($subtitle.name -eq $languageName -and $subtitle.hi -eq $false) {
                    return $subtitle.path
                }
            }
        }

        return $null
    } catch {
        return $null
    }
}
