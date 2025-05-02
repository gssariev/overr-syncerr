function Get-GPTTranslationChunked {
    param (
        [string]$text,
        [string]$sourceLang,
        [string]$targetLang
    )

    $openAiUrl = "https://api.openai.com/v1/chat/completions"
    $maxBytesPerRequest = [int]$env:MAX_REQUEST_BYTES
    $chunkOverlap = [int]$env:CHUNK_OVERLAP
    $delayBetweenRequests = [int]$env:REQUEST_DELAY

    $lines = $text -split "(?<=\n)"
    $chunks = @()
    $currentChunk = @()
    $currentByteCount = 0

    foreach ($line in $lines) {
        $lineByteCount = [System.Text.Encoding]::UTF8.GetByteCount($line)
        $currentByteCount += $lineByteCount
        $currentChunk += $line

        if ($currentByteCount -ge $maxBytesPerRequest) {
            $chunks += $currentChunk -join ""
            $currentChunk = @()
            $currentByteCount = 0
        }
    }

    if ($currentChunk.Count -gt 0) {
        $chunks += $currentChunk -join ""
    }

    $translatedText = ""
    $chunksRemaining = $chunks.Count
    $estimatedTotalTime = $chunksRemaining * $delayBetweenRequests
    Write-Host "Subtitle file is being translated by GPT..."
    Write-Host "Estimated time: approximately $estimatedTotalTime seconds for $chunksRemaining chunks.`n"

    for ($i = 0; $i -lt $chunks.Count; $i++) {
        $chunk = $chunks[$i]
        if (-not [string]::IsNullOrWhiteSpace($chunk)) {
            $chunkByteSize = [System.Text.Encoding]::UTF8.GetByteCount($chunk)
            $remainingChunks = $chunks.Count - $i - 1
            $remainingTime = $remainingChunks * $delayBetweenRequests
            Write-Host "Translating chunk $($i + 1) of $($chunks.Count) ($chunkByteSize bytes)... Estimated time remaining: $remainingTime seconds"

            $promptText = [string]::Format(
                "Translate from {0} to {1}. Keep all timestamps and sentence structures exactly the same. Do not add any extra comments, metadata, or formatting. Only translate the spoken lines into {1}, and preserve the subtitle formatting:",
                $sourceLang, $targetLang
            ) + "`n" + $chunk

            $requestBody = @{
                "model"    = $modelGPT
                "messages" = @(
                    @{
                        "role"    = "system"
                        "content" = "You are a helpful assistant that translates subtitles while preserving the subtitle format."
                    },
                    @{
                        "role"    = "user"
                        "content" = $promptText
                    }
                )
                "max_tokens" = $maxTokens
            }

            $jsonBody = $requestBody | ConvertTo-Json -Depth 3 -Compress
            $utf8Body = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)

            try {
                $response = Invoke-RestMethod -Uri $openAiUrl -Method Post -Headers @{
                    "Authorization" = "Bearer $openAiApiKey"
                    "Content-Type"  = "application/json"
                } -Body $utf8Body

                $translatedText += $response.choices[0].message.content.Trim() + "`n"
                Start-Sleep -Seconds $delayBetweenRequests
            }
            catch {
                Write-Host "Failed to call OpenAI GPT for chunk $($i + 1): $_"
                return $null
            }
        }
    }

    $translatedText = $translatedText -replace '```plaintext', '' -replace '```', '' -replace "\r?\n{2,}", "`n"
    $translatedText = $translatedText -replace "(\d{2}:\d{2}:\d{2},\d{3} --> \d{2}:\d{2}:\d{2},\d{3})\r?\n\1", "$1"

    return $translatedText
}
