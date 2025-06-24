. /app/functions/Misc/Log-Message.ps1
. /app/functions/Mediux/Get-MediuxShowSets.ps1
. /app/functions/Mediux/Get-MediuxMovieSetId.ps1
. /app/functions/Mediux/Upload-SeasonPoster.ps1
. /app/functions/Mediux/Upload-TitleCard.ps1
. /app/functions/Mediux/Upload-Poster.ps1
. /app/functions/Mediux/Get-CleanTitle.ps1
. /app/functions/Plex/Labels/Remove-TagFromMedia.ps1

$plexToken = $env:PLEX_TOKEN
$plexHost  = $env:PLEX_HOST
$enableMediaAvailableHandling = $env:ENABLE_MEDIA_AVAILABLE_HANDLING -eq "true"
$maxAgeDays = [int]($env:MISSING_POSTER_MAX_AGE_DAYS ?? 30)

function Invoke-MissingPosterRetryScan {
    param (
        [string]$jsonPath = "/mnt/usr/missing_posters.json"
    )
    Write-Host "Invoke-MissingPosterRetryScan started at $(Get-Date)"

    if (-not (Test-Path $jsonPath)) {
        Log-Message -Type "INF" -Message "No missing posters file found."
        return
    }

# Ensure $entries is always an array, and skip if it's empty/null
$entries = Get-Content $jsonPath | ConvertFrom-Json

# Force $entries to always be an array
if ($entries -eq $null) { $entries = @() }
elseif ($entries -isnot [System.Collections.IEnumerable] -or $entries -is [string]) { $entries = @($entries) }

if (-not $entries -or $entries.Count -eq 0) {
    Log-Message -Type "INF" -Message "No missing poster entries. Skipping check."
    return
}
    
    $remaining = @()
    $now = [datetime]::UtcNow

    foreach ($entry in $entries) {
        # Always check for age and remove old entries
        # Defensive check for empty/null entries
    if (-not $entry) { continue }

    # Robustly get firstMissing
    $firstMissing = $null
    if ($entry.PSObject.Properties["firstMissing"] -and $entry.firstMissing) {
        $firstMissing = [datetime]$entry.firstMissing
    } elseif ($entry.PSObject.Properties["timestamp"] -and $entry.timestamp) {
        $firstMissing = [datetime]$entry.timestamp
    }
    if (-not $firstMissing) {
        Log-Message -Type "WRN" -Message "No valid firstMissing/timestamp in entry, skipping entry."
        continue
    }

    $ageDays = ($now - $firstMissing).TotalDays
        $ageDays = ($now - $firstMissing).TotalDays
        if ($ageDays -ge $maxAgeDays) {
            $displayTitle = $entry.title
if (-not $displayTitle) { $displayTitle = $entry.showTitle }
if (-not $displayTitle) { $displayTitle = $entry.type }
Log-Message -Type "INF" -Message "Max retry age ($maxAgeDays days) reached for $displayTitle [$($entry.ratingKey)] - removing from retry queue."

            continue
        }

        $type     = $entry.type
        $tmdbId   = $entry.tmdbId
        $setId    = $entry.PSObject.Properties["setId"] ? $entry.setId : $null
        $ratingKey= $entry.ratingKey
        $missing  = $entry.missing
        $timestamp = $null
if ($entry.PSObject.Properties["timestamp"] -and $entry.timestamp) {
    $timestamp = [datetime]$entry.timestamp
}

        $preferredUsernames = $env:MEDIUX_PREFERRED_USERNAMES -split ',' | ForEach-Object { $_.Trim() }
        $cleanVersion = $env:CLEAN_VERSION -eq "true"

        if ($type -eq "show") {
            $title    = $entry.showTitle
            $season   = $entry.season
            $episode  = $entry.episode

            Log-Message -Type "INF" -Message "🔄 Retrying Mediux posters for $title S$season E$episode (SetID: $setId)..."
            $setInfo = Get-MediuxShowSets -tmdbId $tmdbId -title $title -year $null -cleanVersion $cleanVersion -preferredUsernames $preferredUsernames

            # Find correct set if setId is present
            $targetSet = $null
            if ($setId) {
                if ($setInfo -and $setInfo.setId -eq $setId) {
                    $targetSet = $setInfo
                } elseif ($setInfo -and ($setInfo | Get-Member -Name "Values")) {
                    $targetSet = $setInfo.Values | Where-Object { $_.id -eq $setId } | Select-Object -First 1
                }
            } else {
                $targetSet = $setInfo
            }

            [string[]]$retryMissing = @()
            if (-not $targetSet) {
                Log-Message -Type "WRN" -Message "No Mediux set with SetID $setId found for $title ($tmdbId)"
                $retryMissing = $missing
            } else {
                $setDateUpdated = $null
                if ($targetSet.PSObject.Properties["date_updated"]) {
                    $setDateUpdated = [datetime]$targetSet.date_updated
                }
                if ($setDateUpdated -and $setDateUpdated -le $timestamp) {
                    Log-Message -Type "INF" -Message "SetID $setId has not been updated since $timestamp. Skipping retry."
                    $retryMissing = $missing
                } else {
                    if ($missing -contains "season") {
                        $seasonPoster = $targetSet.seasonPosters | Where-Object { $_.season -eq $season } | Select-Object -First 1
                        if ($seasonPoster) {
                            $posterUrl = "https://api.mediux.pro/assets/$($seasonPoster.id)"
                            Upload-SeasonPoster -ratingKey $ratingKey -seasonNumber $season -posterUrl $posterUrl -plexToken $plexToken -plexHost $plexHost
                        } else {
                            $retryMissing += "season"
                        }
                    }
                    if ($missing -contains "titlecard") {
                        $titleCard = $targetSet.titleCards | Where-Object { $_.season -eq $season -and $_.episode -eq $episode } | Select-Object -First 1
                        if ($titleCard) {
                            $posterUrl = "https://api.mediux.pro/assets/$($titleCard.id)"
                            Upload-TitleCard -showRatingKey $ratingKey -seasonNumber $season -episodeNumber $episode -posterUrl $posterUrl -plexToken $plexToken -plexHost $plexHost
                        } else {
                            $retryMissing += "titlecard"
                        }
                    }
                }
            }
            if ($retryMissing.Count -gt 0) {
                # Always set firstMissing if not present
                if (-not $entry.PSObject.Properties["firstMissing"]) {
                    $entry | Add-Member -MemberType NoteProperty -Name "firstMissing" -Value $firstMissing
                }
                $entry.missing = $retryMissing
                $remaining += $entry
            }
        }
        elseif ($type -eq "movie") {
            # Always parse title/year from entry, else fetch from Plex
            $title = $null
            $year  = $null
            if ($entry.PSObject.Properties["showTitle"]) { $title = $entry.showTitle }
            if ($entry.PSObject.Properties["year"])      { $year  = $entry.year }
            if (-not $title -or -not $year) {
                if ($ratingKey) {
                    $metadataUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken"
                    try {
                        $metaXml = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
                        $video = $metaXml.MediaContainer.Video
                        if ($video) {
                            $title = $video.title
                            $year  = $video.year
                            Log-Message -Type "DBG" -Message "Parsed movie title/year: $title ($year) for ratingKey $ratingKey"
                        }
                    } catch {
                        Log-Message -Type "WRN" -Message "Could not fetch movie metadata for ratingKey '$ratingKey': $_"
                    }
                }
            }

            Log-Message -Type "INF" -Message "🔄 Retrying Mediux poster for movie $title ($year) TMDB $tmdbId (SetID: $setId)..."
            $setInfo = Get-MediuxMovieSetId `
                -tmdbId $tmdbId `
                -preferredUsernames $preferredUsernames `
                -title $title `
                -year $year `
                -cleanVersion $cleanVersion

            $targetSet = $null
            if ($setId) {
                if ($setInfo -and $setInfo.setId -eq $setId) {
                    $targetSet = $setInfo
                } elseif ($setInfo -and ($setInfo | Get-Member -Name "Values")) {
                    $targetSet = $setInfo.Values | Where-Object { $_.id -eq $setId } | Select-Object -First 1
                }
            } else {
                $targetSet = $setInfo
            }

            [string[]]$retryMissing = @()
            if (-not $targetSet) {
                Log-Message -Type "WRN" -Message "No Mediux movie set with SetID $setId found for TMDB $tmdbId"
                $retryMissing = $missing
            } else {
                $setDateUpdated = $null
                if ($targetSet.PSObject.Properties["date_updated"]) {
                    $setDateUpdated = [datetime]$targetSet.date_updated
                }
                if ($setDateUpdated -and $setDateUpdated -le $timestamp) {
                    Log-Message -Type "INF" -Message "SetID $setId has not been updated since $timestamp. Skipping retry."
                    $retryMissing = $missing
                } else {
                    if ($missing -contains "poster") {
                        if ($targetSet.assetUrl) {
                            if ($ratingKey) {
                                Upload-Poster -ratingKey $ratingKey -posterUrl $targetSet.assetUrl -plexToken $plexToken -plexHost $plexHost
                            } else {
                                Log-Message -Type "WRN" -Message "No ratingKey in missing movie entry for TMDB $tmdbId"
                                $retryMissing += "poster"
                            }
                        } else {
                            $retryMissing += "poster"
                        }
                    }
                }
            }
            if ($retryMissing.Count -gt 0) {
                if (-not $entry.PSObject.Properties["firstMissing"]) {
                    $entry | Add-Member -MemberType NoteProperty -Name "firstMissing" -Value $firstMissing
                }
                $entry.missing = $retryMissing
                $remaining += $entry
            }
        }
        else {
            Log-Message -Type "WRN" -Message "Unknown entry type '$type' in missing posters file."
            $remaining += $entry
        }
    }

    if ($remaining.Count -eq 0) {
    '[]' | Set-Content $jsonPath
} else {
    $remaining | ConvertTo-Json -Depth 5 | Set-Content $jsonPath
}

    Log-Message -Type "SUC" -Message "✅ Retry scan complete. Remaining entries: $($remaining.Count)"
}

Invoke-MissingPosterRetryScan
