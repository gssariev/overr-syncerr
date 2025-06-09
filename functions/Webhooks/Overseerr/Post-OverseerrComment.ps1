function Post-OverseerrComment {
    param ([string]$issueId, [string]$message, [string]$overseerrApiKey, [string]$overseerrUrl)
    $url = "$overseerrUrl/issue/$issueId/comment"
    $body = @{ message = $message } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json" -Headers @{ 'X-Api-Key' = $overseerrApiKey }
        Write-Host "Posted comment to Overseerr issue $issueId"
    } catch {
        Write-Host "Failed to post comment to Overseerr: $_"
    }
}