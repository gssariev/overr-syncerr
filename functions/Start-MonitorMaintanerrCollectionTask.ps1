function Start-MonitorMaintanerrCollectionTask {
    param (
        [string]$maintainerrUrl,
        [string]$maintainerrApiKey,
        [string]$overseerrUrl,
        [string]$overseerrApiKey,
        [int]$collectionIds,
        [int]$unwatchedLimit,
        [int]$limitDays
    )

    Write-Host "Starting Maintanerr collection monitor asynchronously..."

    # Start the asynchronous job and suppress output
    $job = Start-Job -ScriptBlock {
        param (
            $maintainerrUrl, $maintainerrApiKey, $overseerrUrl, $overseerrApiKey, $collectionId, $unwatchedLimit, $limitDays
        )

        Write-Host "Started Maintanerr collection monitor."

        # Main monitoring function with logging enabled
        Monitor-MaintanerrCollection -maintainerrUrl $maintainerrUrl -maintainerrApiKey $maintainerrApiKey `
                                     -overseerrUrl $overseerrUrl -overseerrApiKey $overseerrApiKey `
                                     -collectionId $collectionId -unwatchedLimit $unwatchedLimit `
                                     -limitDays $limitDays
    } -ArgumentList $maintainerrUrl, $maintainerrApiKey, $overseerrUrl, $overseerrApiKey, $collectionId, $unwatchedLimit, $limitDays | Out-Null

    Write-Host "Started asynchronous Maintanerr collection monitor."
}
