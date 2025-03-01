function Log-Message {
    param (
        [string]$Type,
        [string]$Message
    )

    # ANSI escape codes for colors
    $ColorReset = "`e[0m"
    $ColorBlue = "`e[34m"
    $ColorRed = "`e[31m"
    $ColorYellow = "`e[33m"
    $ColorGray = "`e[90m"
    $ColorGreen = "`e[32m"
    $ColorDefault = "`e[37m"

    # Select color based on message type
    $color = switch ($Type) {
        "INF" { $ColorBlue }
        "ERR" { $ColorRed }
        "WRN" { $ColorYellow }
        "DBG" { $ColorGray }
        "SUC" { $ColorGreen }
        default { $ColorDefault }
    }

    # Output the colored type and uncolored message
    Write-Host "$($color)[$Type]$($ColorReset) $Message"
}
