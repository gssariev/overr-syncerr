function Add-TagToMedia {
    param (
        [string]$newTag
    )
	
	 # Ensure Media Available handling is enabled
    if (-not $enableMediaAvailableHandling) {
        Write-Host "Add-TagToMedia is disabled."
        return
    }

    # Ensure that Plex host and token are set
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
    $updateUrl = "$plexHost/library/metadata/$ratingKey" + "?X-Plex-Token=$plexToken&$encodedLabelsString&label.locked=1"
    
    Write-Host "Update URL: $updateUrl"

    try {
        # Send the update request to Plex
        $responseResult = Invoke-RestMethod -Uri $updateUrl -Method Put
        Write-Host "Label added to media item: $($currentLabels -join ', ')"
    } catch {
        Write-Host "Error adding label to media item: $_"
        Write-Host "Request URL: $updateUrl"
    }
}