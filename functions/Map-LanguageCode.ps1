function Map-LanguageCode {
    param (
        [string]$languageCode,
        [hashtable]$languageMap
    )

    if ($languageMap.ContainsKey($languageCode)) {
        return $languageMap[$languageCode]
    } else {
        Write-Host "Language code '$languageCode' not found in the language map."
        return $null  # Or return a default value like "Unknown"
    }
}