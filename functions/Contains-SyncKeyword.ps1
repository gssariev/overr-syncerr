function Contains-SyncKeyword {
    param ([string]$issueMessage, [array]$syncKeywords)
    if ($syncKeywords.Length -eq 0) {
        return $true
    }
    else {
        $lowercaseMessage = $issueMessage.ToLower()
        foreach ($keyword in $syncKeywords) {
            if ($lowercaseMessage.Contains($keyword)) {
                return $true
            }
        }
        return $false
    }
}
