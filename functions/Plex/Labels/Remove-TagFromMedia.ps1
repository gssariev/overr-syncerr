function Remove-TagFromMedia {
    param (
        [string]$removeTag,
        [array]$ratingKeys
    )

    if (-not $enableMediaAvailableHandling) {
        Log-Message -Type "WRN" -Message "Remove-TagFromMedia is disabled."
        return
    }

    if (-not $plexHost -or -not $plexToken) {
        Log-Message -Type "ERR" -Message "Plex host or token not set. Cannot proceed."
        return
    }

    foreach ($ratingKey in $ratingKeys) {
        $metadataUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken"
        Log-Message -Type "INF" -Message "Metadata URL: $metadataUrl"

        try {
            $metadata = Invoke-RestMethod -Uri $metadataUrl -Method Get -ContentType "application/xml"
        } catch {
            Log-Message -Type "ERR" -Message "Error retrieving metadata for ratingKey ${ratingKey}: $_"
            continue
        }

        # ✅ Parse labels from XML properly
        $labelElements = $metadata.MediaContainer.Video.Label
        if (-not $labelElements) {
            $labelElements = $metadata.MediaContainer.Directory.Label
        }

        $currentLabels = @()
        if ($labelElements) {
            if ($labelElements -is [System.Array]) {
                $currentLabels = $labelElements | ForEach-Object { $_.tag }
            } else {
                $currentLabels = @($labelElements.tag)
            }
        }

        # Remove the tag if it exists
        $updatedLabels = $currentLabels | Where-Object { $_ -ne $removeTag }

        if ($updatedLabels.Count -eq $currentLabels.Count) {
            Log-Message -Type "INF" -Message "No '$removeTag' label to remove for RatingKey $ratingKey."
            continue
        }

        $encodedLabels = $updatedLabels | ForEach-Object {
            "label[$($updatedLabels.IndexOf($_))].tag.tag=" + [System.Uri]::EscapeDataString($_)
        }
        $encodedLabelsString = $encodedLabels -join "&"
        $updateUrl = "$plexHost/library/metadata/$ratingKey"+"?X-Plex-Token=$plexToken&$encodedLabelsString&label.locked=1"

        try {
            Invoke-RestMethod -Uri $updateUrl -Method Put
            Log-Message -Type "SUC" -Message "Label '$removeTag' removed from media item (RatingKey: $ratingKey)"
        } catch {
            Log-Message -Type "ERR" -Message "Error removing label from media item (RatingKey: $ratingKey): $_"
            Log-Message -Type "INF" -Message "Request URL: $updateUrl"
        }
    }
}
