function Process-Queue {
    while ($queue.Count -gt 0) {
        $jsonPayload = $queue.Dequeue()
        Write-Output "Processing payload: $jsonPayload"
        Handle-Webhook -jsonPayload $jsonPayload
        Start-Sleep -Seconds 5
    }
    Write-Output "All payloads processed."
}