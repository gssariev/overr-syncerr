function Extract-Offset {
    param (
        [string]$message
    )
    if ($message -match "offset\s+(\d+)") {
        return [int]$matches[1]
    }
    return $null
}