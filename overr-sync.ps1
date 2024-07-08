# Environment Variables
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
$plexToken = $env:PLEX_TOKEN
$plexHost = $env:PLEX_HOST
$animeSectionId = $env:ANIME_SECTION_ID
$port = $env:PORT

# Language Map and Sync Keywords
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

try {
    $syncKeywords = ConvertFrom-Json -InputObject $syncKeywordsJson
} catch {
    $syncKeywords = @('sync', 'out of sync', 'synchronize', 'synchronization')
}

# Define Functions
function Map-LanguageCode {
    param ([string]$issueMessage, [hashtable]$languageMap)
    $lowercaseMessage = $issueMessage.ToLower()
    foreach ($key in $languageMap.Keys) {
        if ($lowercaseMessage.Contains($key)) {
            return $languageMap[$key]
        }
    }
    return 'English'
}

function Contains-SyncKeyword {
    param ([string]$issueMessage, [array]$syncKeywords)
    $lowercaseMessage = $issueMessage.ToLower()
    foreach ($keyword in $syncKeywords) {
        if ($lowercaseMessage.Contains($keyword)) {
            return $true
        }
    }
    return $false
}

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

function Extract-LanguageCodeFromPath {
    param ([string]$subtitlePath)
    $regex = [regex]"\.(?<lang>[a-z]{2,3})(\.hi)?\.srt$"
    $match = $regex.Match($subtitlePath)
    if ($match.Success) {
        return $match.Groups["lang"].Value
    } else {
        return $null
    }
}

function Post-OverseerrComment {
    param ([string]$issueId, [string]$message, [string]$overseerrApiKey, [string]$overseerrUrl)
    $url = "$overseerrUrl/issue/$issueId/comment"
    $body = @{ message = $message } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json" -Headers @{ 'X-Api-Key' = $overseerrApiKey }
        Write-Host "Posted comment to Overseerr issue $issueId"
    } catch {
        Write-Host "Failed to post comment to Overseerr: $_"
    }
}

function Resolve-OverseerrIssue {
    param ([string]$issueId, [string]$overseerrApiKey, [string]$overseerrUrl)
    $url = "$overseerrUrl/issue/$issueId/resolved"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers @{ 'X-Api-Key' = $overseerrApiKey }
        Write-Host "Marked issue $issueId as resolved in Overseerr"
    } catch {
        Write-Host "Failed to mark issue as resolved in Overseerr: $_"
    }
}

# Create a Payload Queue
$queue = [System.Collections.Queue]::new()

# Function to enqueue payloads
function Enqueue-Payload {
    param ([Parameter(Mandatory=$true)] [string]$Payload)
    $queue.Enqueue($Payload)
    Write-Output "Payload enqueued."
}

# Function to process payloads
function Process-Queue {
    while ($queue.Count -gt 0) {
        $jsonPayload = $queue.Dequeue()
        Write-Output "Processing payload: $jsonPayload"
        Handle-Webhook -jsonPayload $jsonPayload
        Start-Sleep -Seconds 5
    }
    Write-Output "All payloads processed."
}

# Define the function to handle the webhook
function Handle-Webhook {
    param ([string]$jsonPayload)

    $payload = $jsonPayload | ConvertFrom-Json

    if ($payload.issue.issue_type -eq "SUBTITLES") {
        Handle-SubtitlesIssue -payload $payload
    } elseif ($payload.issue.issue_type -eq "OTHER" -and $payload.message -match "(?i)add to library") {
        Handle-OtherIssue -payload $payload
    } else {
        Write-Host "Received issue is not handled."
    }
}

# Function to handle 'SUBTITLES' issue type for substitles sync
function Handle-SubtitlesIssue {
    param ([psobject]$payload)

    Write-Host "Subtitle issue detected"

    $is4K = $payload.message -match "(?i)4K"
    $isHI = $payload.message -match "(?i)hi"
    $containsSyncKeyword = Contains-SyncKeyword -issueMessage $payload.message -syncKeywords $syncKeywords
    if (-not $containsSyncKeyword) {
        Write-Host "Issue message does not contain sync keywords, skipping."
        return
    }

    $bazarrApiKey = if ($is4K) { $bazarr4kApiKey } else { $bazarrApiKey }
    $bazarrUrl = if ($is4K) { $bazarr4kUrl } else { $bazarrUrl }
    $radarrApiKey = if ($is4K) { $radarr4kApiKey } else { $radarrApiKey }
    $radarrUrl = if ($is4K) { $radarr4kUrl } else { $radarrUrl }
    $sonarrApiKey = if ($is4K) { $sonarr4kApiKey } else { $sonarrApiKey }
    $sonarrUrl = if ($is4K) { $sonarr4kUrl } else { $sonarrUrl }

    Write-Host "Using bazarrUrl: $bazarrUrl"

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
            $radarrId = $movieId
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

                    Post-OverseerrComment -issueId $payload.issue.issue_id -message "Subtitles have been synced" -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
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

                            Post-OverseerrComment -issueId $payload.issue.issue_id -message "Subtitles have been synced" -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
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
                        Post-OverseerrComment -issueId $payload.issue.issue_id -message "All subtitles have been synced" -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrApiKey
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
}

# Function to handle 'OTHER' issue type for adding user label to Plex media
function Handle-OtherIssue {
    param ([psobject]$payload)

    $subject = $payload.subject
    $label = $payload.issue.reportedBy_username
    $issueType = $payload.issue.issue_type
    $message = $payload.message
    $mediaType = $payload.media.media_type

    Write-Host "Extracted Label: $label"
    Write-Host "Extracted Media Type: $mediaType"
    Write-Host "Extracted Issue Type: $issueType"
    Write-Host "Extracted Message: $message"

    if ($mediaType -eq "movie") {
        $sectionId = "1"
        $mediaTypeForSearch = "1"
    } elseif ($mediaType -eq "tv") {
        $sectionId = "2"
        $mediaTypeForSearch = "2"

        # Additional API call to check seriesType
        $tmdbId = $payload.media.tmdbId
        $seriesLookupUrl = "$overseerrUrl/service/sonarr/lookup/$tmdbId"
        Write-Host "Series Lookup URL: $seriesLookupUrl"
        try {
            $headers = @{
                'X-Api-Key' = $overseerrApiKey
            }
            $seriesDetails = Invoke-RestMethod -Uri $seriesLookupUrl -Method Get -Headers $headers
            if ($seriesDetails[0].seriesType -eq "anime") {
                $sectionId = $animeSectionId
            }
        } catch {
            Write-Host "Error fetching series details: $_"
            return
        }
    } else {
        Write-Host "Unsupported media type: $mediaType"
        return
    }

    if ($subject -match '^(.*?) \((\d{4})\)$') {
        $title = $matches[1].Trim()
        $year = $matches[2]
        Write-Host "Extracted Title: $title"
        Write-Host "Extracted Year: $year"
    } else {
        Write-Host "Unable to extract title and year from the subject: $subject"
        return
    }

    if (-not $plexToken -or -not $plexHost) {
        Write-Host "Plex host or token not set in environment variables"
        return
    }

    $searchUrl = "$plexHost/library/sections/$sectionId/all?type=$mediaTypeForSearch&title=" + [System.Uri]::EscapeDataString($title) + "&year=$year&X-Plex-Token=$plexToken"
    Write-Host "Search URL: $searchUrl"
    try {
        $mediaItems = Invoke-RestMethod -Uri $searchUrl -Method Get -ContentType "application/xml"
    } catch {
        Write-Host "Error contacting Plex server: $_"
        return
    }

    try {
        if ($mediaType -eq "movie") {
            $mediaItem = $mediaItems.MediaContainer.Video | Where-Object { $_.title -eq $title -and $_.year -eq $year }
        } elseif ($mediaType -eq "tv") {
            $mediaItem = $mediaItems.MediaContainer.Directory | Where-Object { $_.title -eq $title -and $_.year -eq $year }
        }
    } catch {
        Write-Host "Error parsing Plex server response: $_"
        return
    }

    if ($null -eq $mediaItem) {
        Write-Host "Media item not found after filtering"
        return
    }

    $ratingKey = $mediaItem.ratingKey
    Write-Host "Extracted Rating Key: $ratingKey"

    $metadataUrl = "$plexHost/library/metadata/$ratingKey" + "?X-Plex-Token=$plexToken"
    Write-Host "Metadata URL: $metadataUrl"
    try {
        $metadata = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
    } catch {
        Write-Host "Error retrieving metadata: $_"
        return
    }

    $currentLabels = @()
    if ($metadata.MediaContainer.Video.Label) {
        $currentLabels = $metadata.MediaContainer.Video.Label | ForEach-Object { $_.tag }
    } elseif ($metadata.MediaContainer.Directory.Label) {
        $currentLabels = $metadata.MediaContainer.Directory.Label | ForEach-Object { $_.tag }
    }
    Write-Host "Current Labels: $($currentLabels -join ', ')"

    if (-not ($currentLabels -contains $label)) {
        $currentLabels += $label
    }
    Write-Host "Updated Labels: $($currentLabels -join ', ')"

    $encodedLabels = $currentLabels | ForEach-Object { "label[$($currentLabels.IndexOf($_))].tag.tag=" + [System.Uri]::EscapeDataString($_) }
    $encodedLabelsString = $encodedLabels -join "&"
    $updateUrl = "$plexHost/library/metadata/$ratingKey" + "?X-Plex-Token=$plexToken&$encodedLabelsString&label.locked=1"
    Write-Host "Label URL: $updateUrl"

    try {
        $responseResult = Invoke-RestMethod -Uri $updateUrl -Method Put
        Write-Host "Label added to media item: $($currentLabels -join ', ')"
        
        $message = "$subject is now available in your library"
        Post-OverseerrComment -issueId $payload.issue.issue_id -message $message -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
    } catch {
        Write-Host "Error adding label to media item: $_"
        Write-Host "Request URL: $updateUrl"
    }
}

# Start the HTTP listener
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://*:$port/")
$listener.Start()
Write-Host "Listening for webhooks on http://localhost:$port/"

while ($true) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    if ($request.HttpMethod -eq "POST") {
        $reader = [System.IO.StreamReader]::new($request.InputStream)
        $jsonPayload = $reader.ReadToEnd()
        $reader.Close()

        Write-Host "Received payload: $jsonPayload"

        Enqueue-Payload -Payload $jsonPayload
        Process-Queue

        $response.StatusCode = 200
        $response.StatusDescription = "OK"
        $response.Close()
    } else {
        $response.StatusCode = 405
        $response.StatusDescription = "Method Not Allowed"
        $response.Close()
    }
}

$listener.Stop()
