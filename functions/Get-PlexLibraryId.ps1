function Get-PlexLibraryIds {
    param (
        [string]$plexHost,
        [string]$plexToken,
        [pscustomobject]$libraryCategories
    )

    $url = "$plexHost/library/sections/all"+"?X-Plex-Token=$plexToken"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/xml"
        $libraries = $response.MediaContainer.Directory

        if (-not $libraries) {
            Log-Message -Type "ERR" -Message "No libraries found in Plex. Ensure the Plex server is running and accessible."
            return @{}  # Return an empty object instead of $null to avoid script crashes
        }

        $libraryIds = @{}

        foreach ($category in $libraryCategories.Keys) {
            $filteredLibraryNames = $libraryCategories[$category] | Where-Object { $_ -and $_.Trim() -ne "" }

            if ($filteredLibraryNames.Count -lt $libraryCategories[$category].Count) {
                Log-Message -Type "WRN" -Message "One or more library names were null or empty in category '$category' and have been ignored."
            }

            # Define correct Plex library types based on category
            $categoryType = switch ($category) {
                "Movies" { "movie" }
                "TV" { "show" }
                "Anime" { "show" } # Anime is categorized as TV in Plex
                Default { "" }
            }

            foreach ($libraryName in $filteredLibraryNames) {
                # Get all matching libraries with the correct type
                $matchingLibraries = $libraries | Where-Object { $_.title -ieq $libraryName -and $_.type -eq $categoryType }
                
                if ($matchingLibraries) {
                    # Ensure $libraryIds[$category] is initialized as an array before adding IDs
                    if (-not $libraryIds.ContainsKey($category)) {
                        $libraryIds[$category] = @()
                    }
                    $libraryIds[$category] += $matchingLibraries.key 

                    Log-Message -Type "SUC" -Message "Library '$libraryName' found in category '$category' with IDs: $($matchingLibraries.key -join ', ')"
                } else {
                    Log-Message -Type "ERR" -Message "Library '$libraryName' of type '$category' not found."
                    if (-not $libraryIds.ContainsKey($category)) {
                        $libraryIds[$category] = @()
                    }
                }
            }
        }

        # Check if any library IDs were found
        if (-not $libraryIds.Keys.Count) {
            Log-Message -Type "WRN" -Message "No valid library IDs were found. Skipping."
            return @{} 
        }

        return $libraryIds
    } catch {
        Log-Message -Type "ERR" -Message "Error fetching Plex library sections: $_"
        return @{}  # Return an empty object instead of $null to prevent crashes
    }
}
