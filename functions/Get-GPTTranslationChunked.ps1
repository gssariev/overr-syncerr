function Get-GPTTranslationChunked {
    param (
        [string]$text,
        [string]$sourceLang,
        [string]$targetLang
    )

    $openAiUrl = "https://api.openai.com/v1/chat/completions"
    $maxBytesPerRequest = [int]$env:MAX_REQUEST_BYTES  # Maximum byte size per request
    $chunkOverlap = [int]$env:CHUNK_OVERLAP  # Overlap of one subtitle line between chunks
    $delayBetweenRequests = [int]$env:REQUEST_DELAY  # Delay between each server call in seconds

    # Split the text into smaller chunks by line
    $lines = $text -split "(?<=\n)"  # Split into lines
    $chunks = @()  # Initialize chunks array
    $currentChunk = @()  # Buffer for building a chunk
    $currentByteCount = 0  # Track byte usage per chunk

    foreach ($line in $lines) {
        # Get byte count for the line
        $lineByteCount = [System.Text.Encoding]::UTF8.GetByteCount($line)
        $currentByteCount += $lineByteCount

        # Add line to the current chunk
        $currentChunk += $line

        # If the chunk exceeds the byte limit, store it and reset
        if ($currentByteCount -ge $maxBytesPerRequest) {
            $chunks += $currentChunk -join ""
            $currentChunk = @()
            $currentByteCount = 0
        }
    }

    # Add any remaining chunk
    if ($currentChunk.Count -gt 0) {
        $chunks += $currentChunk -join ""
    }

    $translatedText = ""

    foreach ($chunk in $chunks) {
        # Skip empty chunks
        if (-not [string]::IsNullOrWhiteSpace($chunk)) {
            $chunkByteSize = [System.Text.Encoding]::UTF8.GetByteCount($chunk)
            Write-Host "Translating chunk of size: $chunkByteSize bytes"

            # Prepare the subtitle prompt with the custom prompt for translation
            $promptText = [string]::Format("Translate from {0} to {1}. Keep all timestamps and sentence structures exactly the same. Do not add any extra comments, metadata, or formatting. Only translate the spoken lines into {1}, and preserve the subtitle formatting:", $sourceLang, $targetLang) + "`n" + $chunk

            # Prepare the JSON body for the request
            $requestBody = @{
                "model" = $modelGPT
                "messages" = @(
                    @{
                        "role" = "system"; 
                        "content" = "You are a helpful assistant that translates subtitles while preserving the subtitle format."
                    },
                    @{
                        "role" = "user"; 
                        "content" = $promptText
                    }
                )
                "max_tokens" = $maxTokens  # Keep this to ensure token limit on OpenAI side
            }

            # Serialize the body and ensure it's encoded in UTF-8
            $jsonBody = $requestBody | ConvertTo-Json -Depth 3 -Compress
            $utf8Body = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)

            # Log the request body for debugging purposes
            Write-Host "Request body: $jsonBody"

            try {
                # Make the API call to OpenAI with explicit UTF-8 encoding
                $response = Invoke-RestMethod -Uri $openAiUrl -Method Post -Headers @{
                    "Authorization" = "Bearer $openAiApiKey"
                    "Content-Type" = "application/json"
                } -Body $utf8Body

                # Append translated chunk to the final result
                $translatedText += $response.choices[0].message.content.Trim() + "`n"

                # Delay between requests
                Start-Sleep -Seconds $delayBetweenRequests
            } catch {
                Write-Host "Failed to call OpenAI GPT for chunk: $_"
                return $null
            }
        }
    }

    # Clean the translated text to remove unwanted symbols or extra text
    $translatedText = $translatedText -replace '```plaintext', '' -replace '```', '' -replace "\r?\n{2,}", "`n"

    # Remove any duplicate lines with timestamps
    $translatedText = $translatedText -replace "(\d{2}:\d{2}:\d{2},\d{3} --> \d{2}:\d{2}:\d{2},\d{3})\r?\n\1", "$1"

    return $translatedText
}