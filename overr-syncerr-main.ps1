$ErrorActionPreference = "Stop"
trap {
    Log-Message -Type "ERR" -Message "Unhandled error: $_"
    exit 1
}

# Import Functions
Get-ChildItem -Path './functions' -Recurse -Filter '*.ps1' |
    Where-Object { $_.Name -ne 'Invoke-MissingPosterRetryScan.ps1' } |
    ForEach-Object { . $_.FullName }


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
$cleanVersion = $env:CLEAN_VERSION -eq "true"
$enableMediux = $env:USE_MEDIUX -eq "true"
$animeLibraryNames = $env:ANIME_LIBRARY_NAME -split ","
$moviesLibraryNames = $env:MOVIES_LIBRARY_NAME -split ","
$seriesLibraryNames = $env:SERIES_LIBRARY_NAME -split ","
$port = $env:PORT
$enableMediaAvailableHandling = $env:ENABLE_MEDIA_AVAILABLE_HANDLING -eq "true"
$queue = [System.Collections.Queue]::new()
$openAiApiKey = $env:OPEN_AI_API_KEY
$useGPT = $env:ENABLE_GPT -eq "true"
$enableKometa = $env:ENABLE_KOMETA -eq "true"
$enableAudioPref = $env:ENABLE_AUDIO_PREF -eq "true"
$enableSubtitlePref = $env:ENABLE_SUB_PREF -eq "true"
$enableSonarrEpisodeHandler = $env:SONARR_EP_TRACKING -eq "true"
$modelGPT = $env:MODEL_GPT
$maxTokens = [int]$env:MAX_TOKENS
$addLabelKeywords = $env:ADD_LABEL_KEYWORDS
$languageMapJson = $env:LANGUAGE_MAP
$syncKeywordsJson = $env:SYNC_KEYWORDS

# Determine Plex availability
$enablePlex = -not ([string]::IsNullOrWhiteSpace($plexHost) -or [string]::IsNullOrWhiteSpace($plexToken))
if (-not $enablePlex) {
    Log-Message -Type "WRN" -Message "Plex host or token is not configured. User labels, subtitle, and audio preferences will be DISABLED."
}

# Default port fallback
if ([string]::IsNullOrWhiteSpace($port)) {
    $port = 8089
    Log-Message -Type "WRN" -Message "PORT environment variable is not set. Defaulting to port 8089."
} elseif (-not ($port -as [int])) {
    $port = 8089
    Log-Message -Type "WRN" -Message "PORT environment variable is invalid. Defaulting to port 8089."
}

# Generate user tokens and preferences
if ($enablePlex -and $enableAudioPref) {
    Log-Message -Type "INF" -Message "Fetching Plex user tokens..."
    Get-PlexUserTokens -plexToken $plexToken -plexClientId $plexClientId

    Log-Message -Type "INF" -Message "Generating user audio preferences..."
    Generate-UserAudioPreferences
} elseif (-not $enablePlex) {
    Log-Message -Type "WRN" -Message "Plex is not enabled. Skipping user subtitle/audio preferences."
} else {
    Log-Message -Type "WRN" -Message "Fetching Plex user tokens and generating preferences is DISABLED."
}

if ($enablePlex -and $enableSubtitlePref) {
    Log-Message -Type "INF" -Message "Fetching Plex user tokens..."
    Get-PlexUserTokens -plexToken $plexToken -plexClientId $plexClientId

    Log-Message -Type "INF" -Message "Generating user subtitle preferences..."
    Generate-UserSubtitlePreferences
} elseif (-not $enablePlex) {
    Log-Message -Type "WRN" -Message "Plex is not enabled. Skipping user subtitle/audio preferences."
} else {
    Log-Message -Type "WRN" -Message "Generating subtitle preferences is DISABLED."
}


# Parse JSON inputs
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

# Organize libraries
$libraryCategories = @{
    "Movies" = $moviesLibraryNames
    "TV"     = $seriesLibraryNames
    "Anime"  = $animeLibraryNames
}

# Fetch section IDs
if ($enablePlex) {
    $libraryIds = Get-PlexLibraryIds -plexHost $plexHost -plexToken $plexToken -libraryCategories $libraryCategories
    $moviesSectionIds = $libraryIds["Movies"]
    $seriesSectionIds = $libraryIds["TV"]
    $animeSectionIds = $libraryIds["Anime"]

    Log-Message -Type "SUC" -Message "Movies Section IDs: $moviesSectionIds"
    Log-Message -Type "SUC" -Message "Series Section IDs: $seriesSectionIds"
    Log-Message -Type "SUC" -Message "Anime Section IDs: $animeSectionIds"
} else {
    Log-Message -Type "WRN" -Message "Skipping Plex section ID fetch due to missing configuration."
}

# Check if monitoring is enabled
$monitorRequests = $env:MONITOR_REQUESTS -eq "true"
$collectionsInterval = [int]$env:COLLECTIONS_INTERVAL

if ($monitorRequests -and $enablePlex) {
    Start-OverseerrRequestMonitor -overseerrUrl $overseerrUrl `
                                  -plexHost $plexHost `
                                  -plexToken $plexToken `
                                  -overseerrApiKey $overseerrApiKey
    Log-Message -Type "INF" -Message "Started Overseerr request monitor."
} elseif (-not $enablePlex) {
    Log-Message -Type "WRN" -Message "Request monitoring skipped: Plex is not enabled."
} else {
    Log-Message -Type "WRN" -Message "Request monitoring is not enabled. Skipping Overseerr request monitor."
}

# Feature info logs
Log-Message -Type "INF" -Message "GPT is $($useGPT ? "used" : "not used") for subtitle translation."
Log-Message -Type ($enableKometa ? "INF" : "WRN") -Message "Kometa is $($enableKometa ? "ENABLED" : "DISABLED")."
Log-Message -Type ($enableAudioPref ? "INF" : "WRN") -Message "Audio preference is $($enableAudioPref ? "ENABLED" : "DISABLED")."

# Read the cron schedule from environment (with a sensible default)
$mediuxCronSchedule = $env:MEDIUX_CRON_SCHEDULE
if ([string]::IsNullOrWhiteSpace($mediuxCronSchedule)) {
    $mediuxCronSchedule = "* * * * *" # Or your default
}

$friendly = Get-FriendlyCronTime $mediuxCronSchedule
Log-Message -Type "INF" -Message "Cron is configured to run missing poster retry at: '$friendly'"


function Parse-IncomingPayload {
    param (
        [System.Net.HttpListenerRequest]$Request
    )

    $reader = [System.IO.StreamReader]::new($Request.InputStream)
    $rawBody = $reader.ReadToEnd()
    $reader.Close()

    if ($Request.ContentType -and $Request.ContentType -like "*multipart/form-data*") {
        if ($rawBody -match 'name="payload"\s+Content-Type:\s*application/json\s+(?<json>{.*})\s+--') {
            $jsonRaw = $matches['json']
            return $jsonRaw
        } else {
            Log-Message -Type "ERR" -Message "Could not parse JSON from multipart payload"
            return $null
        }
    }

    return $rawBody
}



# HTTP listener block
try {
    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://*:$port/")
    $listener.Start()
    Log-Message -Type "INF" -Message "Listening for webhooks on http://localhost:$port/"

    while ($true) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        if ($request.HttpMethod -eq "POST") {
            $jsonPayload = Parse-IncomingPayload -Request $request

            if ($null -ne $jsonPayload) {
                Enqueue-Payload -Payload $jsonPayload
            } else {
                Log-Message -Type "ERR" -Message "Failed to extract payload from request."
            }

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
} catch {
    Log-Message -Type "ERR" -Message "HTTP listener error: $_"
} finally {
    if ($listener) {
        $listener.Stop()
        Log-Message -Type "WRN" -Message "HTTP listener stopped unexpectedly."
    }
}
