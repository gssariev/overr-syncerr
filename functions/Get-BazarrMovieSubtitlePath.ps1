function Get-BazarrMovieSubtitlePath {
    param ([string]$radarrId, [string]$languageName, [bool]$hearingImpaired, [string]$bazarrApiKey, [string]$bazarrUrl)
    $url = "$bazarrUrl/movies?start=0&length=-1&radarrid%5B%5D=$radarrId&apikey=$bazarrApiKey"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        foreach ($movie in $response.data) {
            foreach ($subtitle in $movie.subtitles) {
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