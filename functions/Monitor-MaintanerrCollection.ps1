function Monitor-MaintanerrCollection {
    param (
        [string]$maintainerrUrl,
        [string]$maintainerrApiKey,
        [string]$overseerrUrl,
        [string]$overseerrApiKey,
        [int[]]$collectionIds,
        [int]$unwatchedLimit,
        [int]$movieQuotaLimit,
        [int]$movieQuotaDays,
        [int]$tvQuotaLimit,
        [int]$tvQuotaDays
    )

    # Get libraries from Maintanerr and store key-type pairs in a dictionary
    $librariesDictionary = Get-MaintainerrLibraries -maintainerrUrl $maintainerrUrl -maintainerrApiKey $maintainerrApiKey
    Write-Host "Libraries Dictionary Contents:"
    foreach ($key in $librariesDictionary.Keys) {
        Write-Host "${key}: $($librariesDictionary[$key])"
    }

    foreach ($collectionId in $collectionIds) {
        Write-Host "Fetching collection $collectionId from Maintanerr..."
        $collectionsEndpoint = "$maintainerrUrl/api/collections"
        $response = Invoke-RestMethod -Uri $collectionsEndpoint -Headers @{ 'X-Api-Key' = $maintainerrApiKey } -Method Get
        $collection = $response | Where-Object { $_.id -eq $collectionId }

        if (-not $collection) {
            Write-Host "Collection ID $collectionId not found."
            continue
        }

        $libraryId = [int]$collection.libraryId  # Ensure libraryId is treated as an integer
        Write-Host "Monitoring Collection ID: $collectionId - $($collection.title), Library ID: $libraryId (Type: $($libraryId.GetType().Name))"

        # Verify that libraryId exists in the dictionary to retrieve the library type
        if ($librariesDictionary.ContainsKey($libraryId)) {
            $libraryType = $librariesDictionary[$libraryId]
            Write-Host "Library type identified as: $libraryType"

            foreach ($mediaItem in $collection.media) {
                $tmdbId = $mediaItem.tmdbId
                Write-Host "Processing media item - TMDB ID: $tmdbId, Library ID: $libraryId"

                # Determine which Maintainerr endpoint to call based on library type
                $endpointType = if ($libraryType -eq "movie") { "movie" } elseif ($libraryType -eq "show") { "show" } else { $null }

                if ($endpointType) {
                    # Construct the Maintainerr API endpoint URL for the item
                    $maintainerrEndpoint = "$maintainerrUrl/api/overseerr/$endpointType/$tmdbId"
                    Write-Host "Fetching requester for TMDB ID: $tmdbId from Maintainerr endpoint: $maintainerrEndpoint"

                    # Get the requester directly from the corresponding Maintainerr endpoint
                    $response = Invoke-RestMethod -Uri $maintainerrEndpoint -Headers @{ 'X-Api-Key' = $maintainerrApiKey } -Method Get

                    # Check if mediaInfo and requests are present and retrieve the requester
                    if ($response.mediaInfo -and $response.mediaInfo.requests -and $response.mediaInfo.requests.Count -gt 0) {
                        $requesterUsername = $response.mediaInfo.requests[0].requestedBy.plexUsername
                    } else {
                        Write-Host "No requester found for TMDB ID: $tmdbId"
                        continue
                    }

                    Write-Host "Requester Identifier: $requesterUsername"

                    # Fetch Maintanerr user list and identify user by name
                    $maintanerrUsers = Get-MaintanerrUsers -maintainerrUrl $maintainerrUrl -maintainerrApiKey $maintainerrApiKey
                    $user = $maintanerrUsers | Where-Object { $_.name -eq $requesterUsername }
                    if (-not $user) {
                        Write-Host "Requester $requesterUsername not found in Maintanerr."
                        continue
                    }

                    $userId = $user.id
                    $unwatchedCount = 0  # Initialize unwatched count per user

                    # Check if the user has watched the media
                    $hasWatched = Check-MaintanerrMediaSeen -plexId $mediaItem.plexId -userId $userId -maintainerrUrl $maintainerrUrl -maintainerrApiKey $maintainerrApiKey
                    if (-not $hasWatched) {
                        $unwatchedCount++
                    }

                    Write-Host "$requesterUsername unwatched media - $unwatchedCount/$unwatchedLimit"

                    # If the user exceeds the unwatched limit, set Overseerr limits based on library type
                    if ($unwatchedCount -ge $unwatchedLimit) {
                        Write-Host "User $requesterUsername has exceeded the unwatched limit. Setting Overseerr limits based on library type."
                        
                        # Only set limits for the relevant media type
                        if ($libraryType -eq "movie") {
                            Set-OverseerrUserLimits -username $requesterUsername `
                                                    -overseerrUrl $overseerrUrl `
                                                    -overseerrApiKey $overseerrApiKey `
                                                    -movieQuotaLimit $movieQuotaLimit `
                                                    -movieQuotaDays $movieQuotaDays
                            Write-Host "Set Overseerr movie limits for ${requesterUsername}: $movieQuotaLimit movies every $movieQuotaDays days"
                        } elseif ($libraryType -eq "show") {
                            Set-OverseerrUserLimits -username $requesterUsername `
                                                    -overseerrUrl $overseerrUrl `
                                                    -overseerrApiKey $overseerrApiKey `
                                                    -tvQuotaLimit $tvQuotaLimit `
                                                    -tvQuotaDays $tvQuotaDays
                            Write-Host "Set Overseerr TV show limits for ${requesterUsername}: $tvQuotaLimit TV shows every $tvQuotaDays days"
                        }
                    }
                } else {
                    Write-Host "Library type not recognized for Library ID: $libraryId, skipping..."
                }
            }
        } else {
            Write-Host "Library ID $libraryId not found in the libraries dictionary, skipping..."
        }
    }
}
