function Map-LanguageCode {
    param ([string]$languageCode, [hashtable]$languageMap)
    return $languageMap[$languageCode]
}
