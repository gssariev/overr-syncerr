function Process-Queue {
    $anyPayloadHandled = $false  # Tracks if any payload in this run was handled

    while ($queue.Count -gt 0) {
        $jsonPayload = $queue.Dequeue()
        try {
            $payload = $jsonPayload | ConvertFrom-Json -AsHashtable
            $payloadHandled = $false

            if ($payload.ContainsKey("event") -and $payload["event"] -eq "library.new" -and $payload["Metadata"]["librarySectionType"] -eq "show" -and $payload["Metadata"]["type"] -eq "episode") {
                $title = $payload["Metadata"]["grandparentTitle"]
                $season = $payload["Metadata"]["parentIndex"]
                $episode = $payload["Metadata"]["index"]
                $episodeTitle = $payload["Metadata"]["title"]
                Log-Message -Type "INF" -Message "📺 New episode added: $title - S$("{0:D2}" -f $season)E$("{0:D2}" -f $episode) \"$episodeTitle\""
                $payloadHandled = $true
            } elseif ($payload.ContainsKey("notification_type") -and $payload["notification_type"] -eq "MEDIA_AVAILABLE") {
                $subject = $payload["subject"]
                $username = $payload["request"]?["requestedBy_username"] ?? "Unknown"
                Log-Message -Type "INF" -Message "✅ Media available: $subject (Requested by: $username)"
                $payloadHandled = $true
            } elseif ($payload.ContainsKey("issue") -and $payload["issue"]["issue_type"] -eq "SUBTITLES") {
                $subject = $payload["subject"]
                $message = $payload["message"]
                $username = $payload["issue"]["reportedBy_username"]
                $season = ($payload["extra"] | Where-Object { $_.name -eq "Affected Season" }).value
                $episode = ($payload["extra"] | Where-Object { $_.name -eq "Affected Episode" }).value
                $location = "S$("{0:D2}" -f $season)E$("{0:D2}" -f $episode)"
                Log-Message -Type "INF" -Message "🗣 Subtitle issue reported by $username for $subject ($location): $message"
                $payloadHandled = $true
            } elseif ($payload.ContainsKey("issue") -and $payload["issue"]["issue_type"] -eq "OTHER") {
                $subject = $payload["subject"]
                $message = $payload["message"]
                $username = $payload["issue"]["reportedBy_username"]
                Log-Message -Type "INF" -Message "📌 Other issue by $username for ${subject}: $message"
                $payloadHandled = $true
            } elseif ($payload.ContainsKey("eventType") -and $payload.ContainsKey("series")) {
                $eventType = $payload["eventType"]
                $seriesTitle = $payload["series"]["title"]
                Log-Message -Type "INF" -Message "📡 Sonarr webhook: $eventType event for $seriesTitle"
                $payloadHandled = $true
            }

            if ($payloadHandled) {
                $anyPayloadHandled = $true
            }

            Handle-Webhook -jsonPayload $jsonPayload
        } catch {
            Log-Message -Type "ERR" -Message "Error processing payload: $_"
        }

        Start-Sleep -Seconds 5
    }

    if ($anyPayloadHandled) {
        Log-Message -Type "SUC" -Message "All payloads processed."
    }
}
