function Map-LanguageCode {
    param ([string]$issueMessage, [hashtable]$languageMap)
    $lowercaseMessage = $issueMessage.ToLower()
    foreach ($key in $languageMap.Keys) {
        if ($lowercaseMessage.Contains($key)) {
            return $languageMap[$key]
        }
    }
    return 'English'
}