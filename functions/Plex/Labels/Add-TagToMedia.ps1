function Add-TagToMedia {
    param (
        [string]$newTag,
        [array]$ratingKeys
    )

    # Ensure Media Available handling is enabled
    if (-not $enableMediaAvailableHandling) {
        Log-Message -Type "WRN" -Message "Add-TagToMedia is disabled."
        return
    }

    # Ensure that Plex host and token are set
    if (-not $plexHost -or -not $plexToken) {
        Log-Message -Type "ERR" -Message "Plex host or token not set. Cannot proceed."
        return
    }

    foreach ($ratingKey in $ratingKeys) {
        # Construct the metadata URL for the media item
        $metadataUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken"
        Log-Message -Type "INF" -Message "Metadata URL: $metadataUrl"

        try {
            # Fetch the metadata for the media item
            $metadata = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
        } catch {
            Log-Message -Type "ERR" -Message "Error retrieving metadata for ratingKey ${ratingKey}: $_"
            continue
        }

        # Initialize an empty array for current labels
        $currentLabels = @()

        # Check if the media item has any labels
        if ($metadata.MediaContainer.Video.Label) {
            if ($metadata.MediaContainer.Video.Label -is [System.Array]) {
                # If multiple labels, collect them into an array
                $currentLabels = $metadata.MediaContainer.Video.Label | ForEach-Object { $_.tag }
            } else {
                # If only one label, convert it to an array
                $currentLabels = @($metadata.MediaContainer.Video.Label.tag)
            }
        } elseif ($metadata.MediaContainer.Directory.Label) {
            if ($metadata.MediaContainer.Directory.Label -is [System.Array]) {
                # If multiple labels, collect them into an array
                $currentLabels = $metadata.MediaContainer.Directory.Label | ForEach-Object { $_.tag }
            } else {
                # If only one label, convert it to an array
                $currentLabels = @($metadata.MediaContainer.Directory.Label.tag)
            }
        }

        # Add the new tag if it's not already present in the current labels
        if (-not ($currentLabels -contains $newTag)) {
            $currentLabels += $newTag
        }

        # Encode the labels for the Plex API update
        $encodedLabels = $currentLabels | ForEach-Object { "label[$($currentLabels.IndexOf($_))].tag.tag=" + [System.Uri]::EscapeDataString($_) }
        $encodedLabelsString = $encodedLabels -join "&"
        $updateUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken&$encodedLabelsString&label.locked=1"
        
        Log-Message -Type "INF" -Message "Update URL: $updateUrl"

        try {
            # Send the update request to Plex
            $responseResult = Invoke-RestMethod -Uri $updateUrl -Method Put
            Log-Message -Type "SUC" -Message "Label added to media item (RatingKey: $ratingKey): $($currentLabels -join ', ')"
        } catch {
            Log-Message -Type "ERR" -Message "Error adding label to media item (RatingKey: $ratingKey): $_"
            Log-Message -Type "INF" -Message "Request URL: $updateUrl"
        }
    }
}
