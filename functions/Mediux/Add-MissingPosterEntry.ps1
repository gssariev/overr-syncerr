function Add-MissingPosterEntry {
    param (
        [string]$showTitle,          # For movies, pass the title here too!
        [string]$ratingKey,
        [Nullable[int]]$season,
        [Nullable[int]]$episode,
        [int]$tmdbId,
        [Nullable[int]]$setId,
        [string[]]$missingItems,
        [Nullable[int]]$year = $null, # Add year param for movies
        [string]$jsonPath = "/mnt/usr/missing_posters.json"
    )

    # Decide if this is a movie or a TV entry
    if ($null -eq $season -and $null -eq $episode) {
        $entryType = "movie"
    } else {
        $entryType = "show"
    }

    $now = (Get-Date).ToString("o")

    $entry = [ordered]@{
        type         = $entryType
        tmdbId       = $tmdbId
        setId        = $setId
        missing      = $missingItems
        timestamp    = $now
        firstMissing = $now
    }

    if ($ratingKey) { $entry["ratingKey"] = $ratingKey }

    if ($entryType -eq "show") {
    if ($showTitle) { $entry["showTitle"] = $showTitle }
    if ($season)    { $entry["season"]    = $season }
    if ($episode)   { $entry["episode"]   = $episode }
} else {
    if ($showTitle) { $entry["title"] = $showTitle }
    # Remove "showTitle" if present
    if ($entry.Contains("showTitle")) { $entry.Remove("showTitle") }
}



    # Robust loading: always force to array
    if (Test-Path $jsonPath) {
        $existing = Get-Content $jsonPath -Raw | ConvertFrom-Json
        if ($null -eq $existing) {
            $existing = @()
        } elseif ($existing -is [System.Collections.IEnumerable] -and $existing -isnot [string]) {
            $existing = @($existing)
        } else {
            $existing = @($existing)
        }
    } else {
        $existing = @()
    }

    # Avoid duplicates, and preserve firstMissing if duplicate
    $isDuplicate = $false
    $existingDuplicate = $null
    if ($entryType -eq "show") {
        $existingDuplicate = $existing | Where-Object {
            $_.type -eq "show" -and
            $_.ratingKey -eq $entry.ratingKey -and
            $_.season -eq $entry.season -and
            $_.episode -eq $entry.episode
        } | Select-Object -First 1
    } else {
        $existingDuplicate = $existing | Where-Object {
            $_.type -eq "movie" -and
            $_.tmdbId -eq $entry.tmdbId -and
            ($_.setId -eq $entry.setId -or $null -eq $entry.setId)
        } | Select-Object -First 1
    }

    if ($existingDuplicate) {
        # Use the original firstMissing timestamp
        $entry.firstMissing = $existingDuplicate.firstMissing
        $isDuplicate = $true
    }

    if (-not $isDuplicate) {
        $updated = $existing + $entry
        $updated | ConvertTo-Json -Depth 5 | Set-Content $jsonPath
        if ($entryType -eq "show") {
            Log-Message -Type "INF" -Message "Recorded missing Mediux assets for: $showTitle S$season E$episode"
        } else {
            Log-Message -Type "INF" -Message "Recorded missing Mediux movie poster for $showTitle ($year) with TMDB $tmdbId"
        }
    }
}
