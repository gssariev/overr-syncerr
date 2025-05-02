function Handle-SubtitlesIssue {
    param ([psobject]$payload)


    # Fetch user details from Overseerr API
    $reportedByPlexUsername = $payload.issue.reportedBy_username
    $userEndpoint = "$overseerrUrl/user?take=30&skip=0&sort=created"
    $headers = @{
        "accept" = "application/json"
        "X-Api-Key" = $overseerrApiKey
    }
    
    $locale = "en"  # Default to English if the locale is not found
    
    try {
        # Get the list of users
        $response = Invoke-RestMethod -Uri $userEndpoint -Headers $headers -Method Get
        $users = $response.results

        # Find the user with the matching Plex username
        $user = $users | Where-Object { $_.plexUsername -eq $reportedByPlexUsername }
        if ($user) {
            Log-Message -Type "INF" -Message "User found: $($user.plexUsername)"
            $userId = $user.id
            $userDetailsApiUrl = "$overseerrUrl/user/$userId"

            try {
                $userDetailsResponse = Invoke-RestMethod -Uri $userDetailsApiUrl -Headers $headers -Method Get
                if ($userDetailsResponse.settings -and $userDetailsResponse.settings.locale) {
                    $locale = $userDetailsResponse.settings.locale
                    Log-Message -Type "INF" -Message "User's locale: $locale"
                } else {
                    Log-Message -Type "WRN" -Message "Locale not found in user's settings, using default locale: en"
                }
            } catch {
                Log-Message -Type "ERR" -Message "Failed to fetch detailed user settings: $_"
                Log-Message -Type "INF" -Message "Using default locale."
            }
        } else {
            Log-Message -Type "WRN" -Message "User not found, using default locale."
        }
    } catch {
        Log-Message -Type "ERR" -Message "Failed to fetch user details from Overseerr: $_"
        Log-Message -Type "INF" -Message "Using default locale."
    }

    $is4K = $payload.message -match "(?i)4K"
    $isHI = $payload.message -match "(?i)hi"
    $containsSyncKeyword = Contains-SyncKeyword -issueMessage $payload.message -syncKeywords $syncKeywords
    $containsAdjustBy = $payload.message -match "(?i)adjust by"
    $containsOffset = $payload.message -match "(?i)offset"
    $containsTranslate = $payload.message -match "(?i)translate"
	

    if (-not $containsSyncKeyword -and -not $containsAdjustBy -and -not $containsOffset -and -not $containsTranslate) {
        Log-Message -Type "INF" -Message "Issue message does not contain sync, adjust by, offset, or translate keywords, skipping."
        return
    }

    $offset = Extract-Offset -message $payload.message
    $shiftOffset = ShiftOffset -message $payload.message
    $bazarrApiKey = if ($is4K) { $bazarr4kApiKey } else { $bazarrApiKey }
    $bazarrUrl = if ($is4K) { $bazarr4kUrl } else { $bazarrUrl }
    $radarrApiKey = if ($is4K) { $radarr4kApiKey } else { $radarrApiKey }
    $radarrUrl = if ($is4K) { $radarr4kUrl } else { $radarrUrl }
    $sonarrApiKey = if ($is4K) { $sonarr4kApiKey } else { $sonarrApiKey }
    $sonarrUrl = if ($is4K) { $sonarr4kUrl } else { $sonarrUrl }

    Log-Message -Type "INF" -Message "Using bazarrUrl: $bazarrUrl"

    # Handle movie subtitles
    if ($payload.media.media_type -eq "movie") {
        $tmdbId = $payload.media.tmdbId
        Log-Message -Type "INF" -Message "Fetching movie details from Radarr for tmdbId: $tmdbId"

        try {
            $radarrMovieDetails = Get-RadarrMovieDetails -tmdbId $tmdbId -radarrApiKey $radarrApiKey -radarrUrl $radarrUrl
        } catch {
            WritLog-Message -Type "ERR" -Messagee-Host (Translate-Message -key "MovieDetailsNotFound" -language $locale)
            return
        }

        if ($radarrMovieDetails) {
            $movieId = $radarrMovieDetails.id
            $radarrId = $movieId
            Log-Message -Type "INF" -Message "Movie ID: $movieId"

            if ($containsTranslate) {
                if ($payload.message -match "translate (\w{2}) to (\w{2})") {
                    $sourceLang = $matches[1]
                    $targetLang = $matches[2]
                    Log-Message -Type "INF" -Message "Source language: $sourceLang, Target language: $targetLang"

                    $sourceLanguageName = Map-LanguageCode -languageCode $sourceLang -languageMap $languageMap
                    Log-Message -Type "INF" -Message "Mapped Source Language Name: $sourceLanguageName"
                    $targetLanguageName = Map-LanguageCode -languageCode $targetLang -languageMap $languageMap
                    Log-Message -Type "INF" -Message "Mapped Target Language Name: $targetLanguageName"

                    $newSubtitlePath = Get-BazarrMovieSubtitlePath -radarrId $radarrId -languageName $sourceLanguageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                    Log-Message -Type "INF" -Message "Subtitle Path: $newSubtitlePath"

                    if ($newSubtitlePath) {
                        $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                        $targetLanguageCode = Get-BazarrLanguageCode -languageName $targetLanguageName -bazarrUrl $bazarrUrl -bazarrApiKey $bazarrApiKey
                        if ($targetLanguageCode) {
                            if ($useGPT) {
                                Log-Message -Type "INF" -Message "Translating with GPT"
                                Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "GptTranslateStart" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
								$gptSubtitlePath = Get-GPTTranslationChunked -text (Get-SubtitleText -subtitlePath $newSubtitlePath) -sourceLang $sourceLang -targetLang $targetLang
                                Set-SubtitleText -subtitlePath $newSubtitlePath -text $gptSubtitlePath -targetLang $targetLang
								Log-Message -Type "SUC" -Message "GPT Translation completed"
                                Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                            } else {
                                $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=translate&language=$targetLanguageCode&path=$encodedSubtitlePath&type=movie&id=$movieId&apikey=$bazarrApiKey"
                                Log-Message -Type "INF" -Message "Sending translation request to Bazarr with URL: $bazarrUrlWithParams"
                                Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationStarted" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl 
                                try {
                                    $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                                    Log-Message -Type "INF" -Message "Bazarr response: Translated"
                                    Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                    Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                } catch {
                                    Log-Message -Type "ERR" -Message "Failed to send translation request to Bazarr: $_"
                                }
                            }
                        } else {
                            Log-Message -Type "ERR" -Message "Failed to get Bazarr language code for $targetLanguageName"
                        }
                    } else {
                        Log-Message -Type "ERR" -Message (Translate-Message -key "SubtitlesMissing" -language $locale)
                        Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SubtitlesMissing" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                    }
                } else {
                    Log-Message -Type "ERR" -Message (Translate-Message -key "FailedToParseLanguages" -language $locale)
                }
                return
            }

            # Syncing logic for movies
            $languageName = Map-LanguageCode -languageCode $payload.message.Split()[0] -languageMap $languageMap
            Log-Message -Type "INF" -Message "Mapped Language Name: $languageName"

            $newSubtitlePath = Get-BazarrMovieSubtitlePath -radarrId $radarrId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
            Log-Message -Type "INF" -Message "Subtitle Path: $newSubtitlePath"

            if ($newSubtitlePath) {
                $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                Log-Message -Type "INF" -Message "Extracted Language Code: $languageCode"
                
                $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                if ($containsAdjustBy -and $shiftOffset -ne $null) {
                    $shiftOffsetEncoded = [System.Web.HttpUtility]::UrlEncode($shiftOffset)
                    $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=shift_offset($shiftOffsetEncoded)&language=$languageCode&path=$encodedSubtitlePath&type=movie&id=$movieId&apikey=$bazarrApiKey"
                } elseif ($containsOffset -and $offset -ne $null) {
                    $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=movie&id=$movieId&reference=(a%3A0)&gss=true&max_offset_seconds=$offset&apikey=$bazarrApiKey"
                } else {
                    $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=movie&id=$movieId&reference=(a%3A0)&gss=true&apikey=$bazarrApiKey"
                }
                Log-Message -Type "INF" -Message "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"
                Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SyncStarted" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl

                try {
                    $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                    Log-Message -Type "SUC" -Message "Bazarr response: Synced"
                    Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SyncFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                    Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                } catch {
                    Log-Message -Type "ERR" -Message "Failed to send PATCH request to Bazarr: $_"
                }
            } else {
                Log-Message -Type "ERR" -Message (Translate-Message -key "SubtitlesMissing" -language $locale)
                Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SubtitlesMissing" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
            }
        } else {
            Log-Message -Type "ERR" -Message (Translate-Message -key "MovieDetailsNotFound" -language $locale)
        }

    # Handle TV subtitles
    } elseif ($payload.media.media_type -eq "tv") {
        $tvdbId = $payload.media.tvdbId
        $affectedSeason = $payload.extra | Where-Object { $_.name -eq "Affected Season" } | Select-Object -ExpandProperty value
        $affectedEpisode = $payload.extra | Where-Object { $_.name -eq "Affected Episode" } | Select-Object -ExpandProperty value
        Log-Message -Type "INF" -Message "Fetching seriesId from Sonarr for tvdbId: $tvdbId"

        $seriesId = Get-SonarrSeriesId -tvdbId $tvdbId -sonarrApiKey $sonarrApiKey -sonarrUrl $sonarrUrl
        if ($seriesId) {
            Log-Message -Type "INF" -Message "Series ID: $seriesId"

            if ($affectedEpisode) {
                Log-Message -Type "INF" -Message "Fetching episode details from Sonarr for seriesId: $seriesId, season: $affectedSeason, episode: $affectedEpisode"
                $episodeDetails = Get-SonarrEpisodeDetails -seriesId $seriesId -seasonNumber ([int]$affectedSeason) -episodeNumber ([int]$affectedEpisode) -sonarrApiKey $sonarrApiKey -sonarrUrl $sonarrUrl
                if ($episodeDetails) {
                    $episodeId = $episodeDetails.id
                    $episodeNumber = $episodeDetails.episodeNumber
                    Log-Message -Type "INF" -Message "Episode ID: $episodeId, Episode Number: $episodeNumber"

                    if ($containsTranslate) {
                        if ($payload.message -match "translate (\w{2}) to (\w{2})") {
                            $sourceLang = $matches[1]
                            $targetLang = $matches[2]
                            Log-Message -Type "INF" -Message "Source language: $sourceLang, Target language: $targetLang"

                            $sourceLanguageName = Map-LanguageCode -languageCode $sourceLang -languageMap $languageMap
                            Log-Message -Type "INF" -Message "Mapped Source Language Name: $sourceLanguageName"
                            $targetLanguageName = Map-LanguageCode -languageCode $targetLang -languageMap $languageMap
                            Log-Message -Type "INF" -Message "Mapped Target Language Name: $targetLanguageName"

                            $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $sourceLanguageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                            Log-Message -Type "INF" -Message "Subtitle Path: $newSubtitlePath"

                            if ($newSubtitlePath) {
                                $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                                $targetLanguageCode = Get-BazarrLanguageCode -languageName $targetLanguageName -bazarrUrl $bazarrUrl -bazarrApiKey $bazarrApiKey
                                if ($targetLanguageCode) {
                                    if ($useGPT) {
                                        Log-Message -Type "INF" -Message "Translating with GPT"
										Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "GptTranslateStart" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                        $gptSubtitlePath = Get-GPTTranslationChunked -text (Get-SubtitleText -subtitlePath $newSubtitlePath) -sourceLang $sourceLang -targetLang $targetLang
                                        Set-SubtitleText -subtitlePath $newSubtitlePath -text $gptSubtitlePath -targetLang $targetLang
                                        Log-Message -Type "SUC" -Message "GPT Translation completed"
                                        Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                    } else {
                                        $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=translate&language=$targetLanguageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&apikey=$bazarrApiKey"
                                        Log-Message -Type "INF" -Message "Sending translation request to Bazarr with URL: $bazarrUrlWithParams"
                                        try {
                                            $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                                            Log-Message -Type "SUC" -Message "Bazarr response: Translated"
                                            Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                            Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                        } catch {
                                            Log-Message -Type "ERR" -Message "Failed to send translation request to Bazarr: $_"
                                        }
                                    }
                                } else {
                                    Log-Message -Type "ERR" -Message "Failed to get Bazarr language code for $targetLanguageName"
                                }
                            } else {
                                Log-Message -Type "ERR" -Message (Translate-Message -key "SubtitlesMissing" -language $locale)
                                Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SubtitlesMissing" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                            }
                        } else {
                            Log-Message -Type "ERR" -Message (Translate-Message -key "FailedToParseLanguages" -language $locale)
                        }
                        return
                    }

                    # Syncing logic for single episode
                    $languageName = Map-LanguageCode -languageCode $payload.message.Split()[0] -languageMap $languageMap
                    Log-Message -Type "INF" -Message "Mapped Language Name: $languageName"

                    $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                    Log-Message -Type "INF" -Message "Subtitle Path: $newSubtitlePath"

                    if ($newSubtitlePath) {
                        $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                        Log-Message -Type "INF" -Message "Extracted Language Code: $languageCode"
                        
                        $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                        if ($containsAdjustBy -and $shiftOffset -ne $null) {
                            $shiftOffsetEncoded = [System.Web.HttpUtility]::UrlEncode($shiftOffset)
                            $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=shift_offset($shiftOffsetEncoded)&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&apikey=$bazarrApiKey"
                        } elseif ($containsOffset -and $offset -ne $null) {
                            $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&gss=true&max_offset_seconds=$offset&apikey=$bazarrApiKey"
                        } else {
                            $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&gss=true&apikey=$bazarrApiKey"
                        }
                        Log-Message -Type "INF" -Message "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"
                        Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SyncStarted" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl

                        try {
                            $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                            Log-Message -Type "SUC" -Message "Bazarr response: Synced"
                            Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SyncFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                            Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        } catch {
                            Log-Message -Type "ERR" -Message "Failed to send PATCH request to Bazarr: $_"
                        }
                    } else {
                        Log-Message -Type "ERR" -Message (Translate-Message -key "SubtitlesMissing" -language $locale)
                        Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SubtitlesMissing" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                    }
                } else {
                    Log-Message -Type "ERR" -Message "Episode details not found in Sonarr"
                }

            } else {
                # Syncing logic for multiple episodes
                Log-Message -Type "INF" -Message "Affected Episode missing, fetching all episodes for season: $affectedSeason"
                $episodes = Get-SonarrEpisodesBySeason -seriesId $seriesId -seasonNumber ([int]$affectedSeason) -sonarrApiKey $sonarrApiKey -sonarrUrl $sonarrUrl
                if ($episodes) {
                    if ($containsTranslate) {
                        if ($payload.message -match "translate (\w{2}) to (\w{2})") {
                            $sourceLang = $matches[1]
                            $targetLang = $matches[2]
                            Log-Message -Type "INF" -Message "Source language: $sourceLang, Target language: $targetLang"

                            $sourceLanguageName = Map-LanguageCode -languageCode $sourceLang -languageMap $languageMap
                            Log-Message -Type "INF" -Message "Mapped Source Language Name: $sourceLanguageName"
                            $targetLanguageName = Map-LanguageCode -languageCode $targetLang -languageMap $languageMap
                            Log-Message -Type "INF" -Message "Mapped Target Language Name: $targetLanguageName"

                            Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationStarted" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl

                            foreach ($episode in $episodes) {
                                $episodeId = $episode.id
                                $episodeNumber = $episode.episodeNumber
                                Log-Message -Type "INF" -Message "Processing episode ID: $episodeId, Episode Number: $episodeNumber"

                                $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $sourceLanguageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                                Log-Message -Type "INF" -Message "Subtitle Path: $newSubtitlePath"

                                if ($newSubtitlePath) {
                                    $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                                    $targetLanguageCode = Get-BazarrLanguageCode -languageName $targetLanguageName -bazarrUrl $bazarrUrl -bazarrApiKey $bazarrApiKey
                                    if ($targetLanguageCode) {
                                        if ($useGPT) {
                                            Log-Message -Type "INF" -Message "Translating with GPT"
                                            $gptSubtitlePath = Get-GPTTranslationChunked -text (Get-SubtitleText -subtitlePath $newSubtitlePath) -sourceLang $sourceLang -targetLang $targetLang
                                            Set-SubtitleText -subtitlePath $newSubtitlePath -text $gptSubtitlePath -targetLang $targetLang
                                            Log-Message -Type "SUC" -Message "GPT Translation completed"
                                        } else {
                                            $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=translate&language=$targetLanguageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&apikey=$bazarrApiKey"
                                            Log-Message -Type "INF" -Message "Sending translation request to Bazarr with URL: $bazarrUrlWithParams"
                                            try {
                                                $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                                                Log-Message -Type "SUC" -Message "Bazarr response: Translated"
                                            } catch {
                                                Log-Message -Type "ERR" -Message "Failed to send translation request to Bazarr: $_"
                                            }
                                        }
                                    } else {
                                        Log-Message -Type "ERR" -Message "Failed to get Bazarr language code for $targetLanguageName"
                                    }
                                } else {
                                    Log-Message -Type "INF" -Message (Translate-Message -key "SubtitlesMissing" -language $locale)
                                    Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SubtitlesMissing" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                    Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                }
                            }

                            Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                            Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        } else {
                            Log-Message -Type "ERR" -Message (Translate-Message -key "FailedToParseLanguages" -language $locale)
                        }
                        return
                    }

                    $languageName = Map-LanguageCode -languageCode $payload.message.Split()[0] -languageMap $languageMap
                    Log-Message -Type "INF" -Message "Mapped Language Name: $languageName"
                    
                    Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SyncStarted" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                    
                    $allSubtitlesSynced = $true
                    $failedEpisodes = @()

                    foreach ($episode in $episodes) {
                        $episodeId = $episode.id
                        $episodeNumber = $episode.episodeNumber
                        Log-Message -Type "INF" -Message "Processing episode ID: $episodeId, Episode Number: $episodeNumber"

                        $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                        Log-Message -Type "INF" -Message "Subtitle Path: $newSubtitlePath"

                        if ($newSubtitlePath) {
                            $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                            Log-Message -Type "INF" -Message "Extracted Language Code: $languageCode"
                            
                            $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                            if ($containsAdjustBy -and $shiftOffset -ne $null) {
                                $shiftOffsetEncoded = [System.Web.HttpUtility]::UrlEncode($shiftOffset)
                                $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=shift_offset($shiftOffsetEncoded)&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&apikey=$bazarrApiKey"
                            } elseif ($containsOffset -and $offset -ne $null) {
                                $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&gss=true&max_offset_seconds=$offset&apikey=$bazarrApiKey"
                            } else {
                                $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&gss=true&apikey=$bazarrApiKey"
                            }
                            Log-Message -Type "INF" -Message "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"

                            try {
                                $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                                Log-Message -Type "SUC" -Message "Bazarr response: Synced"
                            } catch {
                                Log-Message -Type "ERR" -Message "Failed to send PATCH request to Bazarr: $_"
                                $allSubtitlesSynced = $false
                                $failedEpisodes += $episodeNumber
                            }
                        } else {
                            Write-Host "Subtitle path not found in Bazarr for episode ID: $episodeId"
                            $allSubtitlesSynced = $false
                            $failedEpisodes += $episodeNumber
                        }
                    }

                    if ($allSubtitlesSynced) {
                        Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SyncFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                    } else {
                        $failedEpisodesStr = ($failedEpisodes | ForEach-Object { "$_" }) -join ", "
                        Post-OverseerrComment -issueId $payload.issue.issue_id -message "$(Translate-Message -key "SubtitlesPartiallySynced" -language $locale) $failedEpisodesStr" -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                    }
                } else {
                    Log-Message -Type "ERR" -Message "No episodes found for season: $affectedSeason"
                }
            }
        } else {
            Log-Message -Type "ERR" -Message "Series ID not found in Sonarr"
        }
    } else {
        Log-Message -Type "ERR" -Message "Unsupported media type: $($payload.media.media_type)"
    }
}
