function Get-MaintainerrLibraries {
    param (
        [string]$maintainerrUrl,
        [string]$maintainerrApiKey
    )

    # Define the endpoint and headers
    $librariesEndpoint = "$maintainerrUrl/api/plex/libraries"
    $headers = @{ 'X-Api-Key' = $maintainerrApiKey }

    # Make the request
    $response = Invoke-RestMethod -Uri $librariesEndpoint -Headers $headers -Method Get
    $librariesDictionary = @{}

    # Store key and type in a dictionary, ensuring the key is stored as an integer
    foreach ($library in $response) {
        $librariesDictionary[[int]$library.key] = $library.type
    }

    return $librariesDictionary
}
