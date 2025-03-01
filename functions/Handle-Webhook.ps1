function Handle-Webhook {
    param ([string]$jsonPayload)

    $payload = $jsonPayload | ConvertFrom-Json

    # Retrieve the ADD_LABEL_KEYWORDS environment variable and convert it from JSON
    $addLabelKeywords = $env:ADD_LABEL_KEYWORDS | ConvertFrom-Json

    # Check for MEDIA_AVAILABLE notification type
    if ($payload.notification_type -eq "MEDIA_AVAILABLE") {
        Handle-MediaAvailable -payload $payload
		if ($enableKometa){
		Trigger-Kometa
		}
    } elseif ($payload.issue.issue_type -eq "SUBTITLES") {
        Handle-SubtitlesIssue -payload $payload
    } elseif ($payload.issue.issue_type -eq "OTHER") {
        # Convert the message to lowercase and trim whitespace
        $message = $payload.message.ToLower().Trim()

        # Check if the message matches any of the "add label" keywords
        $matchFound = $false
        foreach ($keyword in $addLabelKeywords) {
            if ($message -match [regex]::Escape($keyword.Trim())) {
                $matchFound = $true
                break
            }
        }

        if ($matchFound) {
            Handle-OtherIssue -payload $payload
        } else {
            Log-Message -Type "WRN" -Message "Received issue is not handled."
        }
    } else {
        Log-Message -Type "WRN" -Message "Received issue is not handled."
    }
}
