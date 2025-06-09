function Extract-LanguageCodeFromPath {
    param ([string]$subtitlePath)
    $regex = [regex]"\.(?<lang>[a-z]{2,3})(\.hi)?\.srt$"
    $match = $regex.Match($subtitlePath)
    if ($match.Success) {
        return $match.Groups["lang"].Value
    } else {
        return $null
    }
}