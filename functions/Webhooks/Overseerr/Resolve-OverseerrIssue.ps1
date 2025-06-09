function Resolve-OverseerrIssue {
    param ([string]$issueId, [string]$overseerrApiKey, [string]$overseerrUrl)
    $url = "$overseerrUrl/issue/$issueId/resolved"
    
    Write-Host "Marking issue as resolved with URL: $url"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers @{ 'X-Api-Key' = $overseerrApiKey }
        Write-Host "Marked issue $issueId as resolved in Overseerr"
    } catch {
        Write-Host "Failed to mark issue as resolved in Overseerr: $_"
    }
}