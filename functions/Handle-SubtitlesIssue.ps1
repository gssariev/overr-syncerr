function Handle-SubtitlesIssue {
    param (
        [psobject]$payload,
        [bool]$enableHI = $true  # New parameter to control HI subtitles
    )

    Write-Host "Subtitle issue detected"

    # Fetch user details from Overseerr API
    $reportedByPlexUsername = $payload.issue.reportedBy_username
    $userEndpoint = "$overseerrUrl/user?take=30&skip=0&sort=created"
    $headers = @{
        "accept" = "application/json"
        "X-Api-Key" = $overseerrApiKey
    }

    # Default locale settings
    $locale = "en"  # Default to English if the locale is not found

    # Fetch user locale and other details
    try {
        $response = Invoke-RestMethod -Uri $userEndpoint -Headers $headers -Method Get
        $users = $response.results
        $user = $users | Where-Object { $_.plexUsername -eq $reportedByPlexUsername }
        if ($user) {
            Write-Host "User found: $($user.plexUsername)"
            $userId = $user.id
            $userDetailsApiUrl = "$overseerrUrl/user/$userId"
            try {
                $userDetailsResponse = Invoke-RestMethod -Uri $userDetailsApiUrl -Headers $headers -Method Get
                if ($userDetailsResponse.settings -and $userDetailsResponse.settings.locale) {
                    $locale = $userDetailsResponse.settings.locale
                    Write-Host "User's locale: $locale"
                } else {
                    Write-Host "Locale not found in user's settings, using default locale: en"
                }
            } catch {
                Write-Host "Failed to fetch detailed user settings: $_"
                Write-Host "Using default locale."
            }
        } else {
            Write-Host "User not found, using default locale."
        }
    } catch {
        Write-Host "Failed to fetch user details from Overseerr: $_"
        Write-Host "Using default locale."
    }

  # Ensure $isHI is properly initialized to avoid errors
$is4K = $payload.message -match "(?i)4K"
$isHI = if ($enableHI) {
    $true  # Set to true if 'enableHI' is true to prioritize hearing impaired subs
} else {
    $false  # Set to false if 'enableHI' is false
}
$containsSyncKeyword = Contains-SyncKeyword -issueMessage $payload.message -syncKeywords $syncKeywords
$containsAdjustBy = $payload.message -match "(?i)adjust by"
$containsOffset = $payload.message -match "(?i)offset"
$containsTranslate = $payload.message -match "(?i)translate"

    # Skip handling if none of the required keywords are present
    if (-not $containsSyncKeyword -and -not $containsAdjustBy -and -not $containsOffset -and -not $containsTranslate) {
        Write-Host "Issue message does not contain sync, adjust by, offset, or translate keywords, skipping."
        return
    }

    # Set API URLs and keys based on media resolution
    $bazarrApiKey = if ($is4K) { $bazarr4kApiKey } else { $bazarrApiKey }
    $bazarrUrl = if ($is4K) { $bazarr4kUrl } else { $bazarrUrl }
    $radarrApiKey = if ($is4K) { $radarr4kApiKey } else { $radarrApiKey }
    $radarrUrl = if ($is4K) { $radarr4kUrl } else { $radarrUrl }
    $sonarrApiKey = if ($is4K) { $sonarr4kApiKey } else { $sonarrApiKey }
    $sonarrUrl = if ($is4K) { $sonarr4kUrl } else { $sonarrUrl }

    Write-Host "Using bazarrUrl: $bazarrUrl"

    # Handle movie subtitles
    if ($payload.media.media_type -eq "movie") {
        $tmdbId = $payload.media.tmdbId
        Write-Host "Fetching movie details from Radarr for tmdbId: $tmdbId"

        try {
            $radarrMovieDetails = Get-RadarrMovieDetails -tmdbId $tmdbId -radarrApiKey $radarrApiKey -radarrUrl $radarrUrl
        } catch {
            Write-Host (Translate-Message -key "MovieDetailsNotFound" -language $locale)
            return
        }

        if ($radarrMovieDetails) {
            $movieId = $radarrMovieDetails.id
            $radarrId = $movieId
            Write-Host "Movie ID: $movieId, Radarr ID: $radarrId"

            # Check if translation request is present
            if ($containsTranslate) {
                if ($payload.message -match "translate (\w{2}) to (\w{2})") {
                    $sourceLang = $matches[1]
                    $targetLang = $matches[2]
                    Write-Host "Source language: $sourceLang, Target language: $targetLang"

                    $sourceLanguageName = Map-LanguageCode -languageCode $sourceLang -languageMap $languageMap
                    $targetLanguageName = Map-LanguageCode -languageCode $targetLang -languageMap $languageMap
                    Write-Host "Mapped Source Language Name: $sourceLanguageName"
                    Write-Host "Mapped Target Language Name: $targetLanguageName"

                    # Fetch subtitle path based on source language and hearing impairment status
                    $newSubtitlePath = Get-BazarrMovieSubtitlePath -radarrId $radarrId -languageName $sourceLanguageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                    Write-Host "Subtitle Path: $newSubtitlePath"

                    if ($newSubtitlePath) {
                        $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                        $targetLanguageCode = Get-BazarrLanguageCode -languageName $targetLanguageName -bazarrUrl $bazarrUrl -bazarrApiKey $bazarrApiKey
                        if ($targetLanguageCode) {
                            if ($useGPT) {
                                Write-Host "Translating with GPT"
                                Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "GptTranslateStart" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                $gptSubtitlePath = Get-GPTTranslationChunked -text (Get-SubtitleText -subtitlePath $newSubtitlePath) -sourceLang $sourceLang -targetLang $targetLang
                                Set-SubtitleText -subtitlePath $newSubtitlePath -text $gptSubtitlePath -targetLang $targetLang
                                Write-Host "GPT Translation completed"
                                Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                            } else {
                                $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=translate&language=$targetLanguageCode&path=$encodedSubtitlePath&type=movie&id=$movieId&apikey=$bazarrApiKey"
                                Write-Host "Sending translation request to Bazarr with URL: $bazarrUrlWithParams"
                                Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationStarted" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl 
                                try {
                                    $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                                    Write-Host "Bazarr response: Translated"
                                    Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                    Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                } catch {
                                    Write-Host "Failed to send translation request to Bazarr: $_"
                                }
                            }
                        } else {
                            Write-Host "Failed to get Bazarr language code for $targetLanguageName"
                        }
                    } else {
                        Write-Host (Translate-Message -key "SubtitlesMissing" -language $locale)
                        Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SubtitlesMissing" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                    }
                } else {
                    Write-Host (Translate-Message -key "FailedToParseLanguages" -language $locale)
                }
                return
            }

            # Syncing logic for movies
            $languageName = Map-LanguageCode -languageCode $payload.message.Split()[0] -languageMap $languageMap
            Write-Host "Mapped Language Name: $languageName"

            # Fetch subtitle path based on language and hearing impairment status
            $newSubtitlePath = Get-BazarrMovieSubtitlePath -radarrId $radarrId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
            Write-Host "Subtitle Path: $newSubtitlePath"

            if ($newSubtitlePath) {
                $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                Write-Host "Extracted Language Code: $languageCode"
                
                $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                if ($containsAdjustBy -and $shiftOffset -ne $null) {
                    $shiftOffsetEncoded = [System.Web.HttpUtility]::UrlEncode($shiftOffset)
                    $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=shift_offset($shiftOffsetEncoded)&language=$languageCode&path=$encodedSubtitlePath&type=movie&id=$movieId&apikey=$bazarrApiKey"
                } elseif ($containsOffset -and $offset -ne $null) {
                    $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=movie&id=$movieId&reference=(a%3A0)&gss=true&max_offset_seconds=$offset&apikey=$bazarrApiKey"
                } else {
                    $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=movie&id=$movieId&reference=(a%3A0)&gss=true&apikey=$bazarrApiKey"
                }
                Write-Host "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"
                Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SyncStarted" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl

                try {
                    $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                    Write-Host "Bazarr response: Synced"
                    Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SyncFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                    Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                } catch {
                    Write-Host "Failed to send PATCH request to Bazarr: $_"
                }
            } else {
                Write-Host (Translate-Message -key "SubtitlesMissing" -language $locale)
                Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SubtitlesMissing" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
            }
        } else {
            Write-Host (Translate-Message -key "MovieDetailsNotFound" -language $locale)
        }

    # Handle TV subtitles
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
                    $episodeNumber = $episodeDetails.episodeNumber
                    Write-Host "Episode ID: $episodeId, Episode Number: $episodeNumber"

                    # Check for translation request
                    if ($containsTranslate) {
                        if ($payload.message -match "translate (\w{2}) to (\w{2})") {
                            $sourceLang = $matches[1]
                            $targetLang = $matches[2]
                            Write-Host "Source language: $sourceLang, Target language: $targetLang"

                            $sourceLanguageName = Map-LanguageCode -languageCode $sourceLang -languageMap $languageMap
                            $targetLanguageName = Map-LanguageCode -languageCode $targetLang -languageMap $languageMap
                            Write-Host "Mapped Source Language Name: $sourceLanguageName"
                            Write-Host "Mapped Target Language Name: $targetLanguageName"

                            # Fetch subtitle path for translation
                            $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $sourceLanguageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                            Write-Host "Subtitle Path: $newSubtitlePath"

                            if ($newSubtitlePath) {
                                $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                                $targetLanguageCode = Get-BazarrLanguageCode -languageName $targetLanguageName -bazarrUrl $bazarrUrl -bazarrApiKey $bazarrApiKey
                                if ($targetLanguageCode) {
                                    if ($useGPT) {
                                        Write-Host "Translating with GPT"
                                        Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "GptTranslateStart" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                        $gptSubtitlePath = Get-GPTTranslationChunked -text (Get-SubtitleText -subtitlePath $newSubtitlePath) -sourceLang $sourceLang -targetLang $targetLang
                                        Set-SubtitleText -subtitlePath $newSubtitlePath -text $gptSubtitlePath -targetLang $targetLang
                                        Write-Host "GPT Translation completed"
                                        Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                    } else {
                                        $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=translate&language=$targetLanguageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&apikey=$bazarrApiKey"
                                        Write-Host "Sending translation request to Bazarr with URL: $bazarrUrlWithParams"
                                        try {
                                            $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                                            Write-Host "Bazarr response: Translated"
                                            Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                            Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                        } catch {
                                            Write-Host "Failed to send translation request to Bazarr: $_"
                                        }
                                    }
                                } else {
                                    Write-Host "Failed to get Bazarr language code for $targetLanguageName"
                                }
                            } else {
                                Write-Host (Translate-Message -key "SubtitlesMissing" -language $locale)
                                Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SubtitlesMissing" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                            }
                        } else {
                            Write-Host (Translate-Message -key "FailedToParseLanguages" -language $locale)
                        }
                        return
                    }

                    # Syncing logic for single episode
                    $languageName = Map-LanguageCode -languageCode $payload.message.Split()[0] -languageMap $languageMap
                    Write-Host "Mapped Language Name: $languageName"

                    # Fetch subtitle path for syncing
                    $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                    Write-Host "Subtitle Path: $newSubtitlePath"

                    if ($newSubtitlePath) {
                        $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                        Write-Host "Extracted Language Code: $languageCode"
                        
                        $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                        if ($containsAdjustBy -and $shiftOffset -ne $null) {
                            $shiftOffsetEncoded = [System.Web.HttpUtility]::UrlEncode($shiftOffset)
                            $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=shift_offset($shiftOffsetEncoded)&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&apikey=$bazarrApiKey"
                        } elseif ($containsOffset -and $offset -ne $null) {
                            $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&gss=true&max_offset_seconds=$offset&apikey=$bazarrApiKey"
                        } else {
                            $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&gss=true&apikey=$bazarrApiKey"
                        }
                        Write-Host "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"
                        Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SyncStarted" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl

                        try {
                            $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                            Write-Host "Bazarr response: Synced"
                            Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SyncFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                            Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        } catch {
                            Write-Host "Failed to send PATCH request to Bazarr: $_"
                        }
                    } else {
                        Write-Host (Translate-Message -key "SubtitlesMissing" -language $locale)
                        Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SubtitlesMissing" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                    }
                } else {
                    Write-Host "Episode details not found in Sonarr"
                }

            } else {
                # Syncing logic for multiple episodes
                Write-Host "Affected Episode missing, fetching all episodes for season: $affectedSeason"
                $episodes = Get-SonarrEpisodesBySeason -seriesId $seriesId -seasonNumber ([int]$affectedSeason) -sonarrApiKey $sonarrApiKey -sonarrUrl $sonarrUrl
                if ($episodes) {
                    if ($containsTranslate) {
                        if ($payload.message -match "translate (\w{2}) to (\w{2})") {
                            $sourceLang = $matches[1]
                            $targetLang = $matches[2]
                            Write-Host "Source language: $sourceLang, Target language: $targetLang"

                            $sourceLanguageName = Map-LanguageCode -languageCode $sourceLang -languageMap $languageMap
                            Write-Host "Mapped Source Language Name: $sourceLanguageName"
                            $targetLanguageName = Map-LanguageCode -languageCode $targetLang -languageMap $languageMap
                            Write-Host "Mapped Target Language Name: $targetLanguageName"

                            Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationStarted" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl

                            foreach ($episode in $episodes) {
                                $episodeId = $episode.id
                                $episodeNumber = $episode.episodeNumber
                                Write-Host "Processing episode ID: $episodeId, Episode Number: $episodeNumber"

                                $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $sourceLanguageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                                Write-Host "Subtitle Path: $newSubtitlePath"

                                if ($newSubtitlePath) {
                                    $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                                    $targetLanguageCode = Get-BazarrLanguageCode -languageName $targetLanguageName -bazarrUrl $bazarrUrl -bazarrApiKey $bazarrApiKey
                                    if ($targetLanguageCode) {
                                        if ($useGPT) {
                                            Write-Host "Translating with GPT"
                                            $gptSubtitlePath = Get-GPTTranslationChunked -text (Get-SubtitleText -subtitlePath $newSubtitlePath) -sourceLang $sourceLang -targetLang $targetLang
                                            Set-SubtitleText -subtitlePath $newSubtitlePath -text $gptSubtitlePath -targetLang $targetLang
                                            Write-Host "GPT Translation completed"
                                        } else {
                                            $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=translate&language=$targetLanguageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&apikey=$bazarrApiKey"
                                            Write-Host "Sending translation request to Bazarr with URL: $bazarrUrlWithParams"
                                            try {
                                                $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                                                Write-Host "Bazarr response: Translated"
                                            } catch {
                                                Write-Host "Failed to send translation request to Bazarr: $_"
                                            }
                                        }
                                    } else {
                                        Write-Host "Failed to get Bazarr language code for $targetLanguageName"
                                    }
                                } else {
                                    Write-Host (Translate-Message -key "SubtitlesMissing" -language $locale)
                                    Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SubtitlesMissing" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                    Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                                }
                            }

                            Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "TranslationFinished" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                            Resolve-OverseerrIssue -issueId $payload.issue.issue_id -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                        } else {
                            Write-Host (Translate-Message -key "FailedToParseLanguages" -language $locale)
                        }
                        return
                    }

                    $languageName = Map-LanguageCode -languageCode $payload.message.Split()[0] -languageMap $languageMap
                    Write-Host "Mapped Language Name: $languageName"
                    
                    Post-OverseerrComment -issueId $payload.issue.issue_id -message (Translate-Message -key "SyncStarted" -language $locale) -overseerrApiKey $overseerrApiKey -overseerrUrl $overseerrUrl
                    
                    $allSubtitlesSynced = $true
                    $failedEpisodes = @()

                    foreach ($episode in $episodes) {
                        $episodeId = $episode.id
                        $episodeNumber = $episode.episodeNumber
                        Write-Host "Processing episode ID: $episodeId, Episode Number: $episodeNumber"

                        $newSubtitlePath = Get-BazarrEpisodeSubtitlePath -seriesId $seriesId -episodeId $episodeId -languageName $languageName -hearingImpaired $isHI -bazarrApiKey $bazarrApiKey -bazarrUrl $bazarrUrl
                        Write-Host "Subtitle Path: $newSubtitlePath"

                        if ($newSubtitlePath) {
                            $languageCode = Extract-LanguageCodeFromPath -subtitlePath $newSubtitlePath
                            Write-Host "Extracted Language Code: $languageCode"
                            
                            $encodedSubtitlePath = [System.Web.HttpUtility]::UrlEncode($newSubtitlePath)
                            if ($containsAdjustBy -and $shiftOffset -ne $null) {
                                $shiftOffsetEncoded = [System.Web.HttpUtility]::UrlEncode($shiftOffset)
                                $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=shift_offset($shiftOffsetEncoded)&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&apikey=$bazarrApiKey"
                            } elseif ($containsOffset -and $offset -ne $null) {
                                $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&gss=true&max_offset_seconds=$offset&apikey=$bazarrApiKey"
                            } else {
                                $bazarrUrlWithParams = "$bazarrUrl/subtitles?action=sync&language=$languageCode&path=$encodedSubtitlePath&type=episode&id=$episodeId&reference=(a%3A0)&gss=true&apikey=$bazarrApiKey"
                            }
                            Write-Host "Sending PATCH request to Bazarr with URL: $bazarrUrlWithParams"

                            try {
                                $bazarrResponse = Invoke-RestMethod -Uri $bazarrUrlWithParams -Method Patch
                                Write-Host "Bazarr response: Synced"
                            } catch {
                                Write-Host "Failed to send PATCH request to Bazarr: $_"
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

# Supporting function: Get-BazarrMovieSubtitlePath
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

        # Fallback to non-hi subtitles
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

# Supporting function: Get-BazarrEpisodeSubtitlePath
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

        # Fallback to non-hi subtitles
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

