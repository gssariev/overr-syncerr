function Get-BazarrLanguageCode {
        param (
            [string]$languageName,
            [string]$bazarrUrl,
            [string]$bazarrApiKey
        )

        $url = "$bazarrUrl/system/languages"
        try {
            $response = Invoke-RestMethod -Uri $url -Method Get -Headers @{ "X-API-KEY" = $bazarrApiKey }
            $language = $response | Where-Object { $_.name -eq $languageName }
            return $language.code2
        } catch {
            Write-Host "Failed to fetch languages from Bazarr: $_"
            return $null
        }
    }