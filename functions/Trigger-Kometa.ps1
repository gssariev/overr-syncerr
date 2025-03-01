function Trigger-Kometa {
    Log-Message -Type "INF" -Message "Applying Kometa overlays. Please wait..."

    $dockerArgs = @(
        "run",
        "--rm",
        "-v", $kometaConfig,
        "kometateam/kometa",
        "--run"
    )

    # Create separate temporary files for output and error logs
    $stdoutFile = New-TemporaryFile
    $stderrFile = New-TemporaryFile

    try {
        Start-Process -FilePath "docker" -ArgumentList $dockerArgs -NoNewWindow -Wait -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        Log-Message -Type "SUC" -Message "Kometa overlays applied successfully."
    } catch {
        Log-Message -Type "ERR" -Message "Error executing Kometa: $_"
    } finally {
        # Cleanup temp files
        Remove-Item -Path $stdoutFile -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $stderrFile -Force -ErrorAction SilentlyContinue
    }
}
