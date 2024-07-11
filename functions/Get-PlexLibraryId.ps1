function Get-PlexLibraryIds {
    param (
        [string]$plexHost,
        [string]$plexToken,
        [string[]]$libraryNames
    )

    $url = "$plexHost/library/sections/all?X-Plex-Token=$plexToken"
 
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/xml"
        $libraries = $response.MediaContainer.Directory

        $libraryIds = @{}

        foreach ($libraryName in $libraryNames) {
            $library = $libraries | Where-Object { $_.title -ieq $libraryName }
            if ($null -ne $library) {
                $libraryIds[$libraryName] = $library.key
       
            } else {
                Write-Host "Library '$libraryName' not found."
                $libraryIds[$libraryName] = $null
            }
        }

        return $libraryIds
    } catch {
        Write-Host "Error fetching Plex library sections: $_"
        return $null
    }
}
