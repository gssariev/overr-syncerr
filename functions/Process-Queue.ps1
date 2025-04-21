function Process-Queue {
    while ($queue.Count -gt 0) {
        $jsonPayload = $queue.Dequeue()
        Log-Message -Type "INF" -Message "Processing payload: $jsonPayload"
        Handle-Webhook -jsonPayload $jsonPayload
        Start-Sleep -Seconds 5
    }
    Log-Message -Type "SUC" -Message "All payloads processed."
}