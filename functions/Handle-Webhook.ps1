function Handle-Webhook {
    param ([string]$jsonPayload)

    $payload = $jsonPayload | ConvertFrom-Json

    if ($payload.issue.issue_type -eq "SUBTITLES") {
        Handle-SubtitlesIssue -payload $payload
    } elseif ($payload.issue.issue_type -eq "OTHER" -and $payload.message -match "(?i)add to library") {
        Handle-OtherIssue -payload $payload
    } else {
        Write-Host "Received issue is not handled."
    }
}