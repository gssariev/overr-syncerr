function Get-BazarrMovieSubtitlePath {
    param ([string]$radarrId, [string]$languageName, [bool]$hearingImpaired, [string]$bazarrApiKey, [string]$bazarrUrl)
    
    $url = "$bazarrUrl/movies?start=0&length=-1&radarrid%5B%5D=$radarrId&apikey=$bazarrApiKey"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get

        # Try to find hearing-impaired subtitles first (if $hearingImpaired is true)
        if ($hearingImpaired) {
            foreach ($movie in $response.data) {
                foreach ($subtitle in $movie.subtitles) {
                    if ($subtitle.name -eq $languageName -and $subtitle.hi -eq $true) {
                        return $subtitle.path
                    }
                }
            }
        }

        # If no 'hi' subtitles are found or if $hearingImpaired is false, try to get non-hi subtitles
        foreach ($movie in $response.data) {
            foreach ($subtitle in $movie.subtitles) {
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
