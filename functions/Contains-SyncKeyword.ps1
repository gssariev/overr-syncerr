function Contains-SyncKeyword {
    param ([string]$issueMessage, [array]$syncKeywords)
    $lowercaseMessage = $issueMessage.ToLower()
    foreach ($keyword in $syncKeywords) {
        if ($lowercaseMessage.Contains($keyword)) {
            return $true
        }
    }
    return $false
}