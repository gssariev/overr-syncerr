function Map-LanguageCode {
    param ([string]$languageCode, [hashtable]$languageMap)
    if (-not $languageCode) {
        if ($languageMap.count -eq 1) {
            return $($languageMap.Values)
        }
        else {
            return $($languageMap.Values)[0]
        }
    }
    else {
        return $languageMap[$languageCode]
    }
}
