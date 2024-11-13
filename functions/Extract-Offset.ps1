function Extract-Offset {
    param (
        [string]$message
    )
    if ($message -match "offset\s+(\d+)") {
        $offsetValue = [int]$matches[1]
        if ($offsetValue -ge 0 -and $offsetValue -le 60) {
            return 60
        } elseif ($offsetValue -ge 61 -and $offsetValue -le 120) {
            return 120
        } elseif ($offsetValue -ge 121 -and $offsetValue -le 300) {
            return 300
        } elseif ($offsetValue -ge 301 -and $offsetValue -le 600) {
            return 600
        } else {
            return $offsetValue
        }
    }
    return $null
}
