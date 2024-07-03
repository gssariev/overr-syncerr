# Read environment variables for API keys and URLs
$bazarrApiKey = $env:BAZARR_API_KEY
$bazarrUrl = $env:BAZARR_URL
$radarrApiKey = $env:RADARR_API_KEY
$radarrUrl = $env:RADARR_URL
$sonarrApiKey = $env:SONARR_API_KEY
$sonarrUrl = $env:SONARR_URL
$bazarr4kApiKey = $env:BAZARR_4K_API_KEY
$bazarr4kUrl = $env:BAZARR_4K_URL
$radarr4kApiKey = $env:RADARR_4K_API_KEY
$radarr4kUrl = $env:RADARR_4K_URL
$sonarr4kApiKey = $env:SONARR_4K_API_KEY
$sonarr4kUrl = $env:SONARR_4K_URL
$port = $env:PORT

# Read the language map from the environment variable and convert it from JSON
$languageMapJson = $env:LANGUAGE_MAP

try {
    $languageMapPSObject = ConvertFrom-Json -InputObject $languageMapJson
    $languageMap = @{}
    $languageMapPSObject.psobject.Properties | ForEach-Object {
        $languageMap.Add($_.Name, $_.Value)
    }
} catch {
    $languageMap = @{}
}

# Define a function to map language codes to names
function Map-LanguageCode {
    param (
        [string]$issueMessage,
        [hashtable]$languageMap
    )

    $lowercaseMessage = $issueMessage.ToLower()
    foreach ($key in $languageMap.Keys) {
        if ($lowercaseMessage.Contains($key)) {
            return $languageMap[$key]
        }
    }
    return 'English'  # Default language
}

# Function to get seriesId from Sonarr using tvdbId
function Get-SonarrSeriesId {
    param (
        [string]$tvdbId,
        [string]$sonarrApiKey,
        [string]$sonarrUrl
    )
    $url = "$sonarrUrl/series?tvdbId=$tvdbId&includeSeasonImages=false&apikey=$sonarrApiKey"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        return $response.id
    } catch {
        return $null
    }
}

# Function to get episode details from Sonarr using seriesId, seasonNumber, and episodeNumber
function Get-SonarrEpisodeDetails {
    param (
        [string]$seriesId,
        [int]$seasonNumber,
        [int]$episodeNumber,
        [string]$sonarrApiKey,
        [string]$sonarrUrl
    )
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

# Function to get movie subtitle path from Bazarr using radarrId
function Get-BazarrMovieSubtitlePath {
    param (
        [string]$radarrId,
        [string]$languageName,
        [bool]$hearingImpaired,
        [string]$bazarrApiKey,
        [string]$bazarrUrl
    )
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

# Function to get episode subtitle path from Bazarr using seriesId and episodeId
function Get-BazarrEpisodeSubtitlePath {
    param (
        [string]$seriesId,
        [string]$episodeId,
        [string]$languageName,
        [bool]$hearingImpaired,
        [string]$bazarrApiKey,
        [string]$bazarrUrl
    )
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

# Function to extract language code from subtitle path
function Extract-LanguageCodeFromPath {
    param (
        [string]$subtitlePath
    )
    $regex = [regex]"\.(?<lang>[a-z]{2,3})(\.hi)?\.srt$"
    $match = $regex.Match($subtitlePath)
    if ($match.Success) {
        return $match.Groups["lang"].Value
    } else {
        return $null
    }
}

# Define the function to handle the webhook
function Handle-Webhook {
    param (
        [string]$jsonPayload
    )

    $payload = $jsonPayload | ConvertFrom-Json

    if ($payload.issue.issue_type -eq "SUBTITLES") {
        Write-Host "Subtitle issue detected"

        # Check if the issue message contains '4K'
        $is4K = $payload.message -match "(?i)4K"

        # Check if the issue message contains 'HI' for hearing impaired
        $isHI = $payload.message -match "(?i)hi"

        # Use the appropriate API keys and URLs based on whether the media is 4K
        if ($is4K) {
            $bazarrApiKey = $bazarr4kApiKey
            $bazarrUrl = $bazarr4kUrl
            $radarrApiKey = $radarr4kApiKey
            $radarrUrl = $radarr4kUrl
            $sonarrApiKey = $sonarr4kApiKey
            $sonarrUrl = $sonarr4kUrl
        }

        if ($payload.media.media_type -eq "movie") {
            $tmdbId = $payload.media.tmdbId
            Write-Host "Fetching movie details from Radarr for tmdbId: $tmdbId"

            try {
                $radarrMovieDetails = Invoke-RestMethod -Uri "$radarrUrl/movie?tmdbId=$tmdbId&apikey=$radarrApiKey" -Method Get
            } catch {
                Write-Host "Failed to get movie details from Radarr: $_"
                return
            }

            if ($radarrMovieDetails) {
                $movieId = $radarrMovieDetails.id
                $radarrId = $movieId  # Use the Radarr movie ID directly
                Write-Host "Movie ID: $movieId, Radarr ID: $radarrId"

                $languageName = Map-LanguageCode -issueMessage $payload.message -languageMap $languageMap
                Write-Host "Mapped Language Name: $languageName"

                $newSubtitlePath = Get-BazarrMovieSubtitlePath -radarrId $radarrId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                Write-Host "New Subtitle Path: $newSubtitlePath"

                if ($newSubtitlePath) {
                    $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                    Write-Host "Extracted Language Code: $languageCode"
                    
                    $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                    $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=movie&id=$movieId&reference=(a%3A0)&apikey=$bazarrApiKey"
                    Write-Host "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"

                    try {
                        $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                        Write-Host "Bazarr response: $bazarrResponse"
                    } catch {
                        Write-Host "Failed to send PATCH request to Bazarr: $_"
                    }
                } else {
                    Write-Host "Subtitle path not found in Bazarr"
                }
            } else {
                Write-Host "Movie details not found in Radarr"
            }
        } elseif ($payload.media.media_type -eq "tv") {
            $tvdbId = $payload.media.tvdbId
            $affectedSeason = $payload.extra | Where-Object { $_.name -eq "Affected Season" } | Select-Object -ExpandProperty value
            $affectedEpisode = $payload.extra | Where-Object { $_.name -eq "Affected Episode" } | Select-Object -ExpandProperty value
            Write-Host "Fetching seriesId from Sonarr for tvdbId: $tvdbId"

            $seriesId = Get-SonarrSeriesId -tvdbId $tvdbId -sonarrApiKey $sonarrApiKey -sonarrUrl $sonarrUrl
            if ($seriesId) {
                Write-Host "Series ID: $seriesId"
                Write-Host "Fetching episode details from Sonarr for seriesId: $seriesId, season: $affectedSeason, episode: $affectedEpisode"

                $episodeDetails = Get-SonarrEpisodeDetails -seriesId $seriesId -seasonNumber ([int]$affectedSeason) -episodeNumber ([int]$affectedEpisode) -sonarrApiKey $sonarrApiKey -sonarrUrl $sonarrUrl

                if ($episodeDetails) {
                    $episodeId = $episodeDetails.id
                    $episodeFileId = $episodeDetails.episodeFileId
                    Write-Host "Episode ID: $episodeId, Episode File ID: $episodeFileId"

                    $languageName = Map-LanguageCode -issueMessage $payload.message -languageMap $languageMap
                    Write-Host "Mapped Language Name: $languageName"

                    $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                    Write-Host "New Subtitle Path: $newSubtitlePath"

                    if ($newSubtitlePath) {
                        $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                        Write-Host "Extracted Language Code: $languageCode"
                        
                        $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                        $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&apikey=$bazarrApiKey"
                        Write-Host "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"

                        try {
                            $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                            Write-Host "Bazarr response: $bazarrResponse"
                        } catch {
                            Write-Host "Failed to send PATCH request to Bazarr: $_"
                        }
                    } else {
                        Write-Host "Subtitle path not found in Bazarr"
                    }
                } else {
                    Write-Host "Episode details not found in Sonarr"
                }
            } else {
                Write-Host "Series ID not found in Sonarr"
            }
        } else {
            Write-Host "Unsupported media type: $($payload.media.media_type)"
        }
    } else {
        Write-Host "Received issue is not of type 'SUBTITLES'"
    }
}

# Set up an HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:$port/")
$listener.Start()
Write-Host "Listening for webhooks on http://localhost:$port/"

while ($true) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    if ($request.HttpMethod -eq "POST") {
        $reader = New-Object System.IO.StreamReader $request.InputStream
        $jsonPayload = $reader.ReadToEnd()
        $reader.Close()

        Write-Host "Received payload: $jsonPayload"

        # Handle the webhook
        Handle-Webhook -jsonPayload $jsonPayload

        # Send a response
        $response.StatusCode = 200
        $response.StatusDescription = "OK"
        $response.Close()
    } else {
        $response.StatusCode = 405
        $response.StatusDescription = "Method Not Allowed"
        $response.Close()
    }
}

# Stop the listener (use Ctrl+C to stop the script)
$listener.Stop()
