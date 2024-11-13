function Handle-Watchlist {
    param (
        [string]$overseerrUrl,
        [string]$plexHost,
        [string]$plexToken,
        [string]$overseerrApiKey,
        [int]$requestIntervalCheck,
        [string]$moviesSectionId,
        [string]$seriesSectionId,
        [string]$animeSectionId
    )

    Write-Host "Starting background job to monitor Overseerr watchlists."

    $job = Start-Job -ScriptBlock {
        param($overseerrUrl, $plexHost, $plexToken, $overseerrApiKey, $checkInterval, $moviesSectionId, $seriesSectionId, $animeSectionId)

        function Add-TagToMedia {
            param (
                [string]$newTag,
                [string]$ratingKey
            )

            # Ensure Plex host and token are set
            if (-not $plexHost -or -not $plexToken) {
                Write-Host "Plex host or token not set. Cannot proceed."
                return
            }

            # Construct the metadata URL for the media item
            $metadataUrl = "$plexHost/library/metadata/$ratingKey" + "?X-Plex-Token=$plexToken"
            Write-Host "Metadata URL: $metadataUrl"

            try {
                # Fetch the metadata for the media item
                $metadata = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
            } catch {
                Write-Host "Error retrieving metadata: $_"
                return
            }

            # Initialize an empty array for current labels
            $currentLabels = @()

            # Check if the media item has any labels, depending on the type (Video or Directory)
            if ($metadata.MediaContainer.Video.Label) {
                if ($metadata.MediaContainer.Video.Label -is [System.Array]) {
                    $currentLabels = $metadata.MediaContainer.Video.Label | ForEach-Object { $_.tag }
                } else {
                    $currentLabels = @($metadata.MediaContainer.Video.Label.tag)
                }
            } elseif ($metadata.MediaContainer.Directory.Label) {
                if ($metadata.MediaContainer.Directory.Label -is [System.Array]) {
                    $currentLabels = $metadata.MediaContainer.Directory.Label | ForEach-Object { $_.tag }
                } else {
                    $currentLabels = @($metadata.MediaContainer.Directory.Label.tag)
                }
            }

            # Add the new tag if it's not already present in the current labels
            if (-not ($currentLabels -contains $newTag)) {
                $currentLabels += $newTag
            } else {
                Write-Host "Tag '$newTag' already exists. Skipping."
                return
            }

            # Encode the labels for the Plex API update
            $encodedLabels = $currentLabels | ForEach-Object { "label[$($currentLabels.IndexOf($_))].tag.tag=" + [System.Uri]::EscapeDataString($_) }
            $encodedLabelsString = $encodedLabels -join "&"
            $updateUrl = "$plexHost/library/metadata/$ratingKey" + "?X-Plex-Token=$plexToken&$encodedLabelsString&label.locked=1"
            
            Write-Host "Update URL: $updateUrl"

            try {
                # Send the update request to Plex
                Invoke-RestMethod -Uri $updateUrl -Method Put
                Write-Host "Label added to media item: $($currentLabels -join ', ')"
            } catch {
                Write-Host "Error adding label to media item: $_"
                Write-Host "Request URL: $updateUrl"
            }
        }

        function Get-RatingKeyByTitleAndYear {
            param (
                [string]$title,
                [string]$tmdbId,
                [string]$tvdbId,
                [string]$mediaType,
                [string]$moviesSectionId,
                [string]$seriesSectionId,
                [string]$animeSectionId
            )

            $sectionId = if ($mediaType -eq "movie") { $moviesSectionId } elseif ($mediaType -eq "tv") { $seriesSectionId } else { $animeSectionId }
            $mediaTypeForSearch = if ($mediaType -eq "movie") { "1" } else { "2" }

            $searchUrl = "$plexHost/library/sections/$sectionId/all?type=$mediaTypeForSearch&title=" + [System.Uri]::EscapeDataString($title) + "&X-Plex-Token=$plexToken"
            Write-Host "Search URL: $searchUrl"

            try {
                $mediaItems = Invoke-RestMethod -Uri $searchUrl -Method Get -ContentType "application/xml"
            } catch {
                Write-Host "Error contacting Plex server: $_"
                return $null
            }

            # Filter for the correct year based on TMDB or TVDB ID
            try {
                if ($mediaType -eq "movie") {
                    $mediaItem = $mediaItems.MediaContainer.Video | Where-Object { 
                        $_.guid -like "*$tmdbId*" -or $_.guid -like "*$tvdbId*" 
                    }
                } elseif ($mediaType -eq "tv") {
                    $mediaItem = $mediaItems.MediaContainer.Directory | Where-Object { 
                        $_.guid -like "*$tmdbId*" -or $_.guid -like "*$tvdbId*" 
                    }
                }
            } catch {
                Write-Host "Error parsing Plex server response: $_"
                return $null
            }

            if ($null -eq $mediaItem) {
                Write-Host "Media item not found after filtering by TMDB or TVDB ID."
                return $null
            }

            return $mediaItem.ratingKey
        }

        while ($true) {
            try {
                # Fetch the list of users
                $userEndpoint = "$overseerrUrl/user?take=100&skip=0&sort=created"
                $headers = @{
                    "accept" = "application/json"
                    "X-Api-Key" = $overseerrApiKey
                }

                try {
                    $userResponse = Invoke-RestMethod -Uri $userEndpoint -Headers $headers -Method Get
                    $users = $userResponse.results
                    Write-Host "Fetched user list successfully."
                } catch {
                    Write-Host "Failed to fetch user list: $_"
                    Start-Sleep -Seconds $checkInterval
                    continue
                }

                foreach ($user in $users) {
                    $userId = $user.id
                    $plexUsername = $user.plexUsername
                    $watchlistEndpoint = "$overseerrUrl/user/$userId/watchlist?page=1"

                    try {
                        $watchlistResponse = Invoke-RestMethod -Uri $watchlistEndpoint -Headers $headers -Method Get
                        $watchlistItems = $watchlistResponse.results

                        Write-Host "Fetched watchlist for user: $plexUsername"

                        foreach ($item in $watchlistItems) {
                            $title = $item.title
                            $mediaType = $item.mediaType
                            $tmdbId = $item.tmdbId
                            $tvdbId = $item.tvdbId

                            Write-Host "Fetching correct ratingKey for $title using TMDB ID: $tmdbId or TVDB ID: $tvdbId"

                            # Fetch the correct ratingKey based on the title and TMDB/TVDB ID
                            $ratingKey = Get-RatingKeyByTitleAndYear -title $title -tmdbId $tmdbId -tvdbId $tvdbId -mediaType $mediaType -moviesSectionId $moviesSectionId -seriesSectionId $seriesSectionId -animeSectionId $animeSectionId

                            if ($null -ne $ratingKey) {
                                Write-Host "Processing watchlist item: $title for user: $plexUsername"
                                Add-TagToMedia -newTag $plexUsername -ratingKey $ratingKey
                            } else {
                                Write-Host "No valid ratingKey found for $title, skipping."
                            }
                        }

                    } catch {
                        Write-Host "Failed to fetch watchlist for user $plexUsername $_"
                    }
                }

                Write-Host "Sleeping for $checkInterval seconds before the next check."
                Start-Sleep -Seconds $checkInterval

            } catch {
                Write-Host "Error occurred during the Overseerr watchlist check: $_"
            }
        }
    } -ArgumentList $overseerrUrl, $plexHost, $plexToken, $overseerrApiKey, $requestIntervalCheck, $moviesSectionId, $seriesSectionId, $animeSectionId

}
