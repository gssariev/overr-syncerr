function Get-MediuxSetId {
    param (
        [Parameter(Mandatory)] [int]$tmdbId,
        [string[]]$preferredUsernames = $env:MEDIUX_PREFERRED_USERNAMES -split ',',
        [string]$title,
        [string]$year,
        [bool]$cleanVersion,
        [string]$accessToken = $env:MEDIUX_TOKEN
    )

    $endpoint = "https://staged.mediux.io/graphql"
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }

    $query = @"
{
  movies_by_id(id: $tmdbId) {
    id
    title
    posters {
      id
      movie_set {
        id
        set_title
        user_created { username }
        date_created
        date_updated
      }
    }
    collection_id {
      movies {
        title
        posters {
          id
          collection_set {
            id
            set_title
            user_created { username }
            date_created
            date_updated
          }
        }
      }
    }
  }
}
"@

    $body = @{ query = $query } | ConvertTo-Json -Depth 3

    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method POST -Headers $headers -Body $body
    } catch {
        Write-Warning "[WRN] Failed to fetch data from Mediux GraphQL: $_"
        return $null
    }

    $movie = $response.data.movies_by_id
    if (-not $movie) {
        Write-Warning "[WRN] No movie found for TMDB ID $tmdbId"
        return $null
    }

    function Group-MovieSets {
        $sets = @{}
        foreach ($poster in $movie.posters) {
            $set = $poster.movie_set
            if ($set -and $set.id) {
                $setId = $set.id
                if (-not $sets.ContainsKey($setId)) {
                    $sets[$setId] = @{
                        id           = $set.id
                        set_title    = $set.set_title
                        user_created = $set.user_created
                        poster_id    = $poster.id
                        source       = "movie"
                    }
                }
            }
        }
        return $sets.Values
    }

    function Group-CollectionSets {
        $collectionPosters = @()
        foreach ($m in $movie.collection_id.movies) {
            foreach ($p in $m.posters) {
                $set = $p.collection_set
                if ($set -and $set.id) {
                    $collectionPosters += @{
                        id           = $set.id
                        set_title    = $set.set_title
                        user_created = $set.user_created
                        poster_id    = $p.id
                        origin_title = $m.title
                        source       = "collection"
                    }
                }
            }
        }
        return $collectionPosters
    }

    function Match-Set {
        param (
            [array]$sets,
            [string]$source
        )

        foreach ($preferredUsername in $preferredUsernames) {
            $userSets = $sets | Where-Object { $_.user_created.username -eq $preferredUsername }
            Write-Host "[DBG] Found $($userSets.Count) $source sets by '$preferredUsername'"

            $expectedSet = "$title ($year) Set".ToLower()
            $selected = $null

            if ($cleanVersion) {
                $selected = $userSets | Where-Object { $_.set_title.ToLower() -eq "clean version" } | Select-Object -First 1
                if ($selected) { return $selected }
            }

            if ($source -eq "movie") {
                $selected = $userSets | Where-Object { $_.set_title.ToLower() -eq $expectedSet } | Select-Object -First 1
                if ($selected) { return $selected }

                $partialTitle = $title.ToLower()
                $selected = $userSets | Where-Object { $_.set_title.ToLower() -like "*$partialTitle*" } | Select-Object -First 1
                if ($selected) {
                    Write-Warning "[WRN] Partial match with full title: '$($selected.set_title)'"
                    return $selected
                }

                $cleanBase = (Get-CleanTitle -title $title).ToLower()
                $selected = $userSets | Where-Object { $_.set_title.ToLower() -like "*$cleanBase*" } | Select-Object -First 1
                if ($selected) {
                    Write-Warning "[WRN] Matched using cleaned base title: '$($selected.set_title)'"
                    return $selected
                }

            } else {
                $filteredUserSets = if (-not $cleanVersion) {
                    $userSets | Where-Object { $_.set_title.ToLower() -ne "clean version" }
                } else {
                    $userSets
                }

                $selected = $filteredUserSets |
                    Where-Object { $_.origin_title -eq $title } |
                    Select-Object -First 1
                if ($selected) {
                    Write-Host "[DBG] Collection set matched originating title '$title'"
                    return $selected
                }

                $cleanBase = (Get-CleanTitle -title $title).ToLower()

                $selected = $filteredUserSets |
                    Where-Object { $_.set_title.ToLower() -like "*$cleanBase*" } |
                    Select-Object -First 1
                if ($selected) {
                    Write-Host "[DBG] Collection set matched cleaned title fallback"
                    return $selected
                }

                $selected = $filteredUserSets |
                    Where-Object {
                        $_.set_title.ToLower() -like "*collection*" -and
                        $_.set_title.ToLower() -like "*$cleanBase*"
                    } |
                    Select-Object -First 1
                if ($selected) {
                    Write-Host "[DBG] Collection set matched loose collection name fallback"
                    return $selected
                }
            }
        }

        return $null
    }

    # Try movie sets first
    $movieSets = Group-MovieSets
    if ($movieSets.Count -gt 0) {
        Write-Host "[DBG] Total movie sets found: $($movieSets.Count)"
        $result = Match-Set -sets:$movieSets -source:"movie"
        if ($result) {
            $assetUrl = "https://api.mediux.pro/assets/$($result.poster_id)"
            Write-Host "[SUC] Selected Movie Set: $($result.set_title) (ID=$($result.id))"
            Write-Host "[SUC] Asset URL: $assetUrl"
            return @{
                setId    = $result.id
                assetId  = $result.poster_id
                assetUrl = $assetUrl
            }
        }
    }

    # Fallback to collection sets
    $collectionSets = Group-CollectionSets
    if ($collectionSets.Count -gt 0) {
        Write-Host "[DBG] Total collection sets found: $($collectionSets.Count)"
        $result = Match-Set -sets:$collectionSets -source:"collection"
        if ($result) {
            $assetUrl = "https://api.mediux.pro/assets/$($result.poster_id)"
            Write-Host "[SUC] Selected Collection Set: $($result.set_title) (ID=$($result.id))"
            Write-Host "[SUC] Asset URL: $assetUrl"
            return @{
                setId    = $result.id
                assetId  = $result.poster_id
                assetUrl = $assetUrl
            }
        }
    }

    Write-Warning "[WRN] No Mediux set matched any uploader or condition."
    return $null
}
