# Import Functions
Get-ChildItem -Path './functions/*.ps1' | ForEach-Object { . $_.FullName }

$requestIntervalCheck = $env:CHECK_REQUEST_INTERVAL
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
$animeLibraryName = $env:ANIME_LIBRARY_NAME
$moviesLibraryName = $env:MOVIES_LIBRARY_NAME
$seriesLibraryName = $env:SERIES_LIBRARY_NAME
$port = $env:PORT
$enableMediaAvailableHandling = $env:ENABLE_MEDIA_AVAILABLE_HANDLING -eq "true"
$queue = [System.Collections.Queue]::new()

$addLabelKeywords = $env:ADD_LABEL_KEYWORDS
$languageMapJson = $env:LANGUAGE_MAP
$syncKeywordsJson = $env:SYNC_KEYWORDS

try {
    $languageMapPSObject = ConvertFrom-Json -InputObject $languageMapJson
    $languageMap = @{}
    $languageMapPSObject.psobject.Properties | ForEach-Object {
        $languageMap.Add($_.Name, $_.Value)
    }
    Write-Host "Language map parsed successfully"
} catch {
    $languageMap = @{}
    Write-Host "Error parsing language map: $_"
}

try {
    $syncKeywords = ConvertFrom-Json -InputObject $syncKeywordsJson
    Write-Host "Sync keywords parsed successfully"
} catch {
    $syncKeywords = @('sync', 'out of sync', 'synchronize', 'synchronization')
    Write-Host "Error parsing sync keywords: $_"
}

# Fetch Plex Library IDs
$libraryNames = @($animeLibraryName, $moviesLibraryName, $seriesLibraryName)
$libraryIds = Get-PlexLibraryIds -plexHost $plexHost -plexToken $plexToken -libraryNames $libraryNames

$animeSectionId = $libraryIds[$animeLibraryName]
$moviesSectionId = $libraryIds[$moviesLibraryName]
$seriesSectionId = $libraryIds[$seriesLibraryName]

Write-Host "Anime Section ID: $animeSectionId"
Write-Host "Movies Section ID: $moviesSectionId"
Write-Host "Series Section ID: $seriesSectionId"


# Check if the environment variable MONITOR_REQUESTS is set to true
$monitorRequests = $env:MONITOR_REQUESTS -eq "true"

if ($monitorRequests) {
    Start-OverseerrRequestMonitor -overseerrUrl $overseerrUrl -plexHost $plexHost -plexToken $plexToken -overseerrApiKey $overseerrApiKey -seriesSectionId $seriesSectionId -animeSectionId $animeSectionId -requestIntervalCheck $requestIntervalCheck
} else {
    Write-Host "Request monitoring is not enabled. Skipping Overseerr request monitor."
}

# HTTP listener
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
