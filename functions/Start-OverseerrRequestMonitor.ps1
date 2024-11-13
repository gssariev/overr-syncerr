function Start-OverseerrRequestMonitor {
    param (
        [string]$overseerrUrl,
        [string]$plexHost,
        [string]$plexToken,
        [string]$overseerrApiKey,
        [string]$seriesSectionId,
        [string]$animeSectionId,
        [int]$requestIntervalCheck
    )
	
    Write-Host "Starting background job to monitor Overseerr requests."

    # Start an asynchronous job to monitor requests
    $job = Start-Job -ScriptBlock {
        param($overseerrUrl, $plexHost, $plexToken, $overseerrApiKey, $seriesSectionId, $animeSectionId, $checkInterval)

        function Add-TagToMedia {
    param (
        [string]$newTag,
        [string]$ratingKey
    )

    # Ensure that Plex host and token are set
    if (-not $plexHost -or -not $plexToken) {
        Write-Host "Plex host or token not set. Cannot proceed."
        return
    }

    # Construct the metadata URL for the media item
    $metadataUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken"
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

    # Check if the media item has any labels (Video or Directory)
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

    Write-Host "Current Labels: $($currentLabels -join ', ')"

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
    $updateUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken&$encodedLabelsString&label.locked=1"

    Write-Host "Update URL: $updateUrl"

    try {
        # Send the update request to Plex
        $responseResult = Invoke-RestMethod -Uri $updateUrl -Method Put
        Write-Host "Label added to media item: $($currentLabels -join ', ')"
    } catch {
        Write-Host "Error adding label to media item: $_"
    }
}

        while ($true) {
            try {
                # Headers with the Overseerr API key
                $headers = @{ 'X-Api-Key' = $overseerrApiKey }

                # Fetch all requests from Overseerr
                $requestsUrl = "$overseerrUrl/request"
                Write-Host "Checking Overseerr requests at: $requestsUrl"

                $allRequests = Invoke-RestMethod -Uri $requestsUrl -Method Get -Headers $headers

                if (-not $allRequests.results) {
                    Write-Host "No requests found."
                    Start-Sleep -Seconds $checkInterval
                    continue
                }

                # Loop through each request and find the ones with status 4 (approved) or 5 (completed)
                foreach ($request in $allRequests.results) {
                    if ($request.media.status -in 4, 5) {
                        Write-Host "Found approved/completed request. Processing media with TMDB ID: $($request.media.tmdbId) or TVDB ID: $($request.media.tvdbId)"

                        $mediaType = $request.media.mediaType
                        $tmdbId = $request.media.tmdbId
                        $tvdbId = $request.media.tvdbId
                        $plexUsername = $request.requestedBy.plexUsername
                        $ratingKey = $request.media.ratingKey

                        Write-Host "Processing $mediaType request for Plex user: $plexUsername with TMDB ID: $tmdbId or TVDB ID: $tvdbId"

                        # Handle different media types
                        if ($mediaType -eq "movie") {
                            Add-TagToMedia -newTag $plexUsername -ratingKey $ratingKey
                        } elseif ($mediaType -eq "tv") {
                            # If tmdbId is null, use tvdbId
                            if ($null -ne $tmdbId) {
                                Write-Host "Using TMDB ID for TV series lookup."
                                Add-TagToMedia -newTag $plexUsername -ratingKey $ratingKey
                            } elseif ($null -ne $tvdbId) {
                                Write-Host "Using TVDB ID for TV series lookup."
                                Add-TagToMedia -newTag $plexUsername -ratingKey $ratingKey
                            } else {
                                Write-Host "No valid TMDB or TVDB ID found. Skipping."
                            }
                        }

                        Write-Host "Tag added successfully for Plex user: $plexUsername."
                    }
                }

                # Sleep for the configured interval before checking again
                Write-Host "Sleeping for $checkInterval seconds before the next check."
                Start-Sleep -Seconds $checkInterval

            } catch {
                Write-Host "Error occurred during the Overseerr request check: $_"
            }
        }
    } -ArgumentList $overseerrUrl, $plexHost, $plexToken, $overseerrApiKey, $seriesSectionId, $animeSectionId, $requestIntervalCheck

}
