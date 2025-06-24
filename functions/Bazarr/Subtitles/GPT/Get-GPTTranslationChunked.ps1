function Get-GPTTranslationChunked {
    param (
        [string]$text,
        [string]$sourceLang,
        [string]$targetLang
    )

    $openAiUrl = "https://api.openai.com/v1/chat/completions"
    $maxTokens = [int]$env:MAX_TOKENS
    $chunkOverlap = [int]$env:CHUNK_OVERLAP
    $chunkBlockTarget = 20   # Number of blocks per chunk. Tune as needed.
    $delayBetweenRequests = [int]$env:REQUEST_DELAY
    $modelGPT = $env:MODEL_GPT
    $openAiApiKey = $env:OPEN_AI_API_KEY

    # Normalize Windows/Unix line endings and split into blocks (SRT blocks are separated by blank lines)
    $text = $text -replace "`r`n", "`n" -replace "`r", "`n"
    $blocks = $text -split "(\n){2,}" | Where-Object { $_.Trim() -ne "" }
    $chunks = @()

    # Chunking with overlap
    $chunkStart = 0
    $blocksCount = $blocks.Count
    while ($chunkStart -lt $blocksCount) {
        $chunkEnd = [Math]::Min($chunkStart + $chunkBlockTarget - 1, $blocksCount - 1)
        $chunkBlocks = $blocks[$chunkStart..$chunkEnd]
        $chunks += ,@($chunkBlocks)
        $chunkStart += ($chunkBlockTarget - $chunkOverlap)
    }

    $translatedChunks = @()
    Write-Host "Total chunks to be translated: $($chunks.Count). Estimated time: $($chunks.Count * $delayBetweenRequests) seconds.`n"

    for ($i = 0; $i -lt $chunks.Count; $i++) {
        $chunkBlocks = $chunks[$i]
        $chunk = $chunkBlocks -join "`n`n"

        if (-not [string]::IsNullOrWhiteSpace($chunk)) {
            $promptText = @"
Translate these subtitles from $sourceLang to $targetLang. For each subtitle block, keep the block number and timestamp exactly as in the input. ONLY translate the dialogue. Do not merge or split blocks. Do not add, remove, or reorder any block. Preserve subtitle formatting exactly.

$chunk
"@

            $requestBody = @{
                "model"    = $modelGPT
                "messages" = @(
                    @{
                        "role"    = "system"
                        "content" = "You are a subtitle translator. Translate ONLY the dialogue in each subtitle block, keeping all numbers, timestamps, and formatting unchanged. Never merge, split, add, remove, or reorder blocks."
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

                $translatedChunk = $response.choices[0].message.content.Trim()
                $translatedChunks += $translatedChunk  # <<-- STORE AS STRING
                Start-Sleep -Seconds $delayBetweenRequests
            }
            catch {
                Write-Host "Failed to call OpenAI GPT for chunk $($i + 1): $_"
                return $null
            }
        }
    }

    # When combining, split each translated chunk into blocks, skip overlap at the block level
    $finalBlocks = @()
    for ($i = 0; $i -lt $translatedChunks.Count; $i++) {
        # split on blank lines, keep only non-empty blocks
        $chunkBlocks = $translatedChunks[$i] -split "(\n){2,}" | Where-Object { $_.Trim() -ne "" }
        if ($i -eq 0) {
            $finalBlocks += $chunkBlocks
        } else {
            if ($chunkBlocks.Count -gt $chunkOverlap) {
                $finalBlocks += $chunkBlocks[$chunkOverlap..($chunkBlocks.Count - 1)]
            }
        }
    }

    # Join blocks with two newlines (SRT format)
    $translatedText = $finalBlocks -join "`n`n"

    # Optional: Cleanup
    $translatedText = $translatedText -replace '```plaintext', '' -replace '```', ''

    return $translatedText
}
