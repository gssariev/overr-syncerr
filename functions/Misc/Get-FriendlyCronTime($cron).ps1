function Get-FriendlyCronTime($cron) {
    $fields = $cron -split '\s+'
    if ($fields.Count -lt 5) { return $cron } # Not valid cron

    $minute = $fields[0]
    $hour   = $fields[1]

    # "0 * * * *" → "Every hour, on the hour"
    if ($minute -eq '0' -and $hour -eq '*') {
        return "Every hour, on the hour"
    }
    # "15 3 * * *" → "At 03:15 every day"
    $minuteInt = 0
    $hourInt = 0
    if ([int]::TryParse($minute, [ref]$minuteInt) -and [int]::TryParse($hour, [ref]$hourInt)) {
        return ("At {0:D2}:{1:D2} every day" -f $hourInt, $minuteInt)
    }
    # "* * * * *" → "Every minute"
    if ($minute -eq '*' -and $hour -eq '*') {
        return "Every minute"
    }
    # "0 */8 * * *" → "Every 8 hours, on the hour"
    $hourMatch = [regex]::Match($hour, '^\*/(\d+)$')
    if ($minute -eq '0' -and $hourMatch.Success) {
        $interval = [int]$hourMatch.Groups[1].Value
        return "Every $interval hours, on the hour"
    }
    # "*/15 * * * *" → "Every 15 minutes"
    $minuteMatch = [regex]::Match($minute, '^\*/(\d+)$')
    if ($minuteMatch.Success -and $hour -eq '*') {
        $interval = [int]$minuteMatch.Groups[1].Value
        return "Every $interval minutes"
    }
    return $cron # fallback to raw cron
}
