function ShiftOffset {
    param (
        [string]$message
    )

    $pattern = "adjust\s+by\s+(-?\d+)\s*(s|ms|m|min)?"

    Write-Host "Matching pattern: $pattern against message: '$message'"
    if ($message -match $pattern) {
        Write-Host "Pattern matched!"
        $number = [int]$matches[1]
        $unit = if ($matches[2]) { $matches[2] } else { "s" } # default to seconds if no unit is specified

        Write-Host "Number: $number, Unit: $unit"

        # Determine the unit and convert to Bazarr format
        switch ($unit) {
            "ms" { return "h=0,m=0,s=0,ms=$number" }
            "m" { return "h=0,m=$number,s=0,ms=0" }
            "min" { return "h=0,m=$number,s=0,ms=0" }
            default { return "h=0,m=0,s=$number,ms=0" } # seconds by default
        }
    } else {
        Write-Host "Pattern did not match."
    }

    return $null
}