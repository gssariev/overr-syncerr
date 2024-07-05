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
$overseerrApiKey = $env:OVERSEERR_API_KEY
$overseerrUrl = $env:OVERSEERR_URL
$port = $env:PORT

# Read the language map from the environment variable and convert it from JSON
$languageMapJson = $env:LANGUAGE_MAP
$syncKeywordsJson = $env:SYNC_KEYWORDS

try {
    $languageMapPSObject = ConvertFrom-Json -InputObject $languageMapJson
    $languageMap = @{}
    $languageMapPSObject.psobject.Properties | ForEach-Object {
        $languageMap.Add($_.Name, $_.Value)
    }
} catch {
    $languageMap = @{}
}

# Read the sync keywords list with fallback
try {
    $syncKeywords = ConvertFrom-Json -InputObject $syncKeywordsJson
} catch {
    $syncKeywords = @('sync', 'out of sync', 'synchronize', 'synchronization')
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

# Function to check if the message contains synchronization-related keywords
function Contains-SyncKeyword {
    param (
        [string]$issueMessage,
        [array]$syncKeywords
    )

    $lowercaseMessage = $issueMessage.ToLower()
    foreach ($keyword in $syncKeywords) {
        if ($lowercaseMessage.Contains($keyword)) {
            return $true
        }
    }
    return $false
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

# Function to get all episodes from Sonarr using seriesId and seasonNumber
function Get-SonarrEpisodesBySeason {
    param (
        [string]$seriesId,
        [int]$seasonNumber,
        [string]$sonarrApiKey,
        [string]$sonarrUrl
    )
    $url = "$sonarrUrl/episode?seriesId=$seriesId&seasonNumber=$seasonNumber&includeImages=false&apikey=$sonarrApiKey"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        return $response
    } catch {
        return $null
    }
}

# Function to get movie details from Radarr using tmdbId
function Get-RadarrMovieDetails {
    param (
        [string]$tmdbId,
        [string]$radarrApiKey,
        [string]$radarrUrl
    )
    $url = "$radarrUrl/movie?tmdbId=$tmdbId&apikey=$radarrApiKey"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        return $response
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

# Function to post a comment to Overseerr issue
function Post-OverseerrComment {
    param (
        [string]$issueId,
        [string]$message,
        [string]$overseerrApiKey,
        [string]$overseerrUrl
    )
    $url = "$overseerrUrl/issue/$issueId/comment"
    $body = @{
        message = $message
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json" -Headers @{ 'X-Api-Key' = $overseerrApiKey }
        Write-Host "Posted comment to Overseerr issue $issueId"
    } catch {
        Write-Host "Failed to post comment to Overseerr: $_"
    }
}

# Function to mark Overseerr issue as resolved
function Resolve-OverseerrIssue {
    param (
        [string]$issueId,
        [string]$overseerrApiKey,
        [string]$overseerrUrl
    )
    $url = "$overseerrUrl/issue/$issueId/resolved"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers @{ 'X-Api-Key' = $overseerrApiKey }
        Write-Host "Marked issue $issueId as resolved in Overseerr"
    } catch {
        Write-Host "Failed to mark issue as resolved in Overseerr: $_"
    }
}

# Create a Queue
$queue = [System.Collections.Queue]::new()

# Function to enqueue payloads
function Enqueue-Payload {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Payload
    )
    $queue.Enqueue($Payload)
    Write-Output "Payload enqueued."
}

# Function to process payloads
function Process-Queue {
    while ($queue.Count -gt 0) {
        $jsonPayload = $queue.Dequeue()
        Write-Output "Processing payload: $jsonPayload"

        # Handle the webhook
        Handle-Webhook -jsonPayload $jsonPayload

        # Wait for 5 seconds before processing the next payload
        Start-Sleep -Seconds 5
    }
    Write-Output "All payloads processed."
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

        # Check if the issue message contains sync keywords
        $containsSyncKeyword = Contains-SyncKeyword -issueMessage $payload.message -syncKeywords $syncKeywords
        if (-not $containsSyncKeyword) {
            Write-Host "Issue message does not contain sync keywords, skipping."
            return
        }

        # Use the appropriate API keys and URLs based on whether the media is 4K
        if ($is4K) {
            $bazarrApiKey = $bazarr4kApiKey
            $bazarrUrl = $bazarr4kUrl
            $radarrApiKey = $radarr4kApiKey
            $radarrUrl = $radarr4kUrl
            $sonarrApiKey = $sonarr4kApiKey
            $sonarrUrl = $sonarr4kUrl
        } else {
            $bazarrApiKey = $env:BAZARR_API_KEY
            $bazarrUrl = $env:BAZARR_URL
            $radarrApiKey = $env:RADARR_API_KEY
            $radarrUrl = $env:RADARR_URL
            $sonarrApiKey = $env:SONARR_API_KEY
            $sonarrUrl = $env:SONARR_URL
        }

        if ($payload.media.media_type -eq "movie") {
            $tmdbId = $payload.media.tmdbId
            Write-Host "Fetching movie details from Radarr for tmdbId: $tmdbId"

            try {
                $radarrMovieDetails = Get-RadarrMovieDetails -tmdbId $tmdbId -radarrApiKey $radarrApiKey -radarrUrl $radarrUrl
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
                Write-Host "Subtitle Path: $newSubtitlePath"

                if ($newSubtitlePath) {
                    $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                    Write-Host "Extracted Language Code: $languageCode"
                    
                    $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                    $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=movie&id=$movieId&reference=(a%3A0)&apikey=$bazarrApiKey"
                    Write-Host "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"

                    try {
                        $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                        Write-Host "Bazarr response: Synced"

                        # Post a comment to Overseerr
                        Post-OverseerrComment -issueId $payload.issue.issue_id -message "Subtitles have been synced" -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl

                        # Resolve the issue in Overseerr
                        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
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

                if ($affectedEpisode) {
                    Write-Host "Fetching episode details from Sonarr for seriesId: $seriesId, season: $affectedSeason, episode: $affectedEpisode"
                    $episodeDetails = Get-SonarrEpisodeDetails -seriesId $seriesId -seasonNumber ([int]$affectedSeason) -episodeNumber ([int]$affectedEpisode) -sonarrApiKey $sonarrApiKey -sonarrUrl $sonarrUrl
                    if ($episodeDetails) {
                        $episodeId = $episodeDetails.id
                        $episodeFileId = $episodeDetails.episodeFileId
                        Write-Host "Episode ID: $episodeId, Episode File ID: $episodeFileId"

                        $languageName = Map-LanguageCode -issueMessage $payload.message -languageMap $languageMap
                        Write-Host "Mapped Language Name: $languageName"

                        $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                        Write-Host "Subtitle Path: $newSubtitlePath"

                        if ($newSubtitlePath) {
                            $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                            Write-Host "Extracted Language Code: $languageCode"
                            
                            $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                            $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&apikey=$bazarrApiKey"
                            Write-Host "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"

                            try {
                                $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                                Write-Host "Bazarr response: Synced"

                                # Post a comment to Overseerr
                                Post-OverseerrComment -issueId $payload.issue.issue_id -message "Subtitles have been synced" -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl

                                # Resolve the issue in Overseerr
                                Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
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
                    Write-Host "Affected Episode missing, fetching all episodes for season: $affectedSeason"
                    $episodes = Get-SonarrEpisodesBySeason -seriesId $seriesId -seasonNumber ([int]$affectedSeason) -sonarrApiKey $sonarrApiKey -sonarrUrl $sonarrUrl
                    if ($episodes) {
                        $languageName = Map-LanguageCode -issueMessage $payload.message -languageMap $languageMap
                        Write-Host "Mapped Language Name: $languageName"

                        $allSubtitlesSynced = $true
                        foreach ($episode in $episodes) {
                            $episodeId = $episode.id
                            Write-Host "Processing episode ID: $episodeId"

                            $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                            Write-Host "Subtitle Path: $newSubtitlePath"

                            if ($newSubtitlePath) {
                                $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                                Write-Host "Extracted Language Code: $languageCode"
                                
                                $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                                $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&apikey=$bazarrApiKey"
                                Write-Host "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"

                                try {
                                    $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                                    Write-Host "Bazarr response: Synced"
                                } catch {
                                    Write-Host "Failed to send PATCH request to Bazarr: $_"
                                    $allSubtitlesSynced = $false
                                }
                            } else {
                                Write-Host "Subtitle path not found in Bazarr for episode ID: $episodeId"
                                $allSubtitlesSynced = $false
                            }
                        }
                        if ($allSubtitlesSynced) {
                            # Post a comment to Overseerr
                            Post-OverseerrComment -issueId $payload.issue.issue_id -message "All subtitles have been synced" -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl

                            # Resolve the issue in Overseerr
                            Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        } else {
                            Write-Host "Not all subtitles were synced successfully"
                        }
                    } else {
                        Write-Host "No episodes found for season: $affectedSeason"
                    }
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

# HTTP listener
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

        # Enqueue the payload
        Enqueue-Payload -Payload $jsonPayload

        # Process the queue
        Process-Queue

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

# Stop the listener
$listener.Stop()
