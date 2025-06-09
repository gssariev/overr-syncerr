function Enqueue-Payload {
    param ([Parameter(Mandatory=$true)] [string]$Payload)
    $queue.Enqueue($Payload)
}