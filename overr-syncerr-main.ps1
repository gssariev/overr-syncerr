# Import Functions
Get-ChildItem -Path './functions/*.ps1' | ForEach-Object { . $_.FullName }

# Parse and set up environment variables
$requestIntervalCheck = $env:CHECK_REQUEST_INTERVAL
$maintainerrUrl = $env:MAINTAINERR_URL
$audioTrackFilter = $env:AUDIO_TRACK_FILTER
$maintainerrApiKey = $env:MAINTAINERR_API_KEY
$unwatchedLimit = [int]$env:UNWATCHED_LIMIT
$movieQuotaLimit = [int]$env:MOVIE_QUOTA_LIMIT
$movieQuotaDays = [int]$env:MOVIE_QUOTA_DAYS
$tvQuotaLimit = [int]$env:TV_QUOTA_LIMIT
$tvQuotaDays = [int]$env:TV_QUOTA_DAYS
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
$plexClientId = $env:SERVER_CLIENTID
$kometaConfig = $env:KOMETA_CONFIG_PATH
$plexToken = $env:PLEX_TOKEN
$plexHost = $env:PLEX_HOST
$animeLibraryName = $env:ANIME_LIBRARY_NAME
$moviesLibraryName = $env:MOVIES_LIBRARY_NAME
$seriesLibraryName = $env:SERIES_LIBRARY_NAME
$port = $env:PORT
$enableMediaAvailableHandling = $env:ENABLE_MEDIA_AVAILABLE_HANDLING -eq "true"
$queue = [System.Collections.Queue]::new()
$openAiApiKey = $env:OPEN_AI_API_KEY
$useGPT = $env:ENABLE_GPT -eq "true"
$enableKometa = $env:ENABLE_KOMETA -eq "true"
$enableAudioPref = $env:ENABLE_AUDIO_PREF -eq "true"
$modelGPT = $env:MODEL_GPT
$maxTokens = [int]$env:MAX_TOKENS

$addLabelKeywords = $env:ADD_LABEL_KEYWORDS
$languageMapJson = $env:LANGUAGE_MAP
$syncKeywordsJson = $env:SYNC_KEYWORDS

# Call function at script startup
if ($enableAudioPref){
Log-Message -Type "INF" -Message "Fetching Plex user tokens..."
Get-PlexUserTokens -plexToken $plexToken -plexClientId $plexClientId
} else {
    Log-Message -Type "WRN" -Message "Fetcing Plex user tokens is DISABLED."
}
# Call function at script startup to ensure the file exists
if ($enableAudioPref){
Log-Message -Type "INF" -Message "Generating user audio preferences..."
Generate-UserAudioPreferences
} else {
    Log-Message -Type "WRN" -Message "Audio Preference generation is DISABLED."
}

try {
    $languageMapPSObject = ConvertFrom-Json -InputObject $languageMapJson
    $languageMap = @{}
    $languageMapPSObject.psobject.Properties | ForEach-Object {
        $languageMap.Add($_.Name, $_.Value)
    }
    Log-Message -Type "SUC" -Message "Language map parsed successfully"
} catch {
    $languageMap = @{}
    Log-Message -Type "ERR" -Message "Error parsing language map: $_"
}

try {
    $syncKeywords = ConvertFrom-Json -InputObject $syncKeywordsJson
    Log-Message -Type "SUC" -Message "Sync keywords parsed successfully"
} catch {
    $syncKeywords = @('sync', 'out of sync', 'synchronize', 'synchronization')
    Log-Message -Type "ERR" -Message "Error parsing sync keywords: $_"
}

# Fetch Plex Library IDs
$libraryNames = @($animeLibraryName, $moviesLibraryName, $seriesLibraryName)
$libraryIds = Get-PlexLibraryIds -plexHost $plexHost -plexToken $plexToken -libraryNames $libraryNames

$animeSectionId = $libraryIds[$animeLibraryName]
$moviesSectionId = $libraryIds[$moviesLibraryName]
$seriesSectionId = $libraryIds[$seriesLibraryName]

Log-Message -Type "SUC" -Message "Anime Section ID: $animeSectionId"
Log-Message -Type "SUC" -Message "Movies Section ID: $moviesSectionId"
Log-Message -Type "SUC" -Message "Series Section ID: $seriesSectionId"

# Check if the environment variable MONITOR_REQUESTS is set to true
$monitorRequests = $env:MONITOR_REQUESTS -eq "true"
$collectionsInterval = [int]$env:COLLECTIONS_INTERVAL

if ($monitorRequests) {
    Start-OverseerrRequestMonitor -overseerrUrl $overseerrUrl `
                                  -plexHost $plexHost `
                                  -plexToken $plexToken `
                                  -overseerrApiKey $overseerrApiKey `
                                  -seriesSectionId $seriesSectionId `
                                  -animeSectionId $animeSectionId `
                                  -requestIntervalCheck $requestIntervalCheck
    Log-Message -Type "INF" -Message "Started Overseerr request monitor."
} else {
    Log-Message -Type "WRN" -Message "Request monitoring is not enabled. Skipping Overseerr request monitor."
}

if ($useGPT) {
    Log-Message -Type "INF" -Message "GPT is used for subtitle translation."
} else {
    Log-Message -Type "INF" -Message "Bazarr (Google API) is used for subtitle translation."
}

if ($enableKometa){
    Log-Message -Type "INF" -Message "Kometa is ENABLED."
} else {
    Log-Message -Type "WRN" -Message "Kometa is DISABLED."
}

if ($enableAudioPref){
    Log-Message -Type "INF" -Message "Audio preference is ENABLED."
} else {
    Log-Message -Type "WRN" -Message "Audio preference is DISABLED."
}

# HTTP listener
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://*:$port/")
$listener.Start()

Log-Message -Type "INF" -Message "Listening for webhooks on http://localhost:$port/"

while ($true) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    if ($request.HttpMethod -eq "POST") {
        $reader = [System.IO.StreamReader]::new($request.InputStream)
        $jsonPayload = $reader.ReadToEnd()
        $reader.Close()

        Log-Message -Type "INF" -Message "Received payload: $jsonPayload"

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
