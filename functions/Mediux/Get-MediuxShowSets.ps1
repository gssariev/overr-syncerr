function Get-MediuxShowSets {
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
  shows_by_id(id: $tmdbId) {
    id
    title
    status
    posters {
      id
      show_set {
        id
        set_title
        user_created { username }
        date_created
        date_updated
      }
    }
    backdrops {
      id
      show_set {
        id
        set_title
        user_created { username }
        date_created
        date_updated
      }
    }
    seasons {
      season_number
      posters {
        id
        show_set {
          id
          set_title
          user_created { username }
          date_created
          date_updated
        }
      }
      episodes {
        episode_number
        episode_title
        titlecards {
          id
          show_set {
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
        Write-Warning "[WRN] Failed to fetch show data from Mediux GraphQL: $_"
        return $null
    }

    $show = $response.data.shows_by_id
    if (-not $show) {
        Write-Warning "[WRN] No show found for TMDB ID $tmdbId"
        return $null
    }

    $setMap = @{}
    $allSeasonPosters = @()
    $allTitleCards = @()

    function Add-SetEntry {
        param ($poster, $set, $type)

        if ($set -and $set.id -and -not $setMap.ContainsKey($set.id)) {
            $setMap[$set.id] = @{
                id           = $set.id
                set_title    = $set.set_title
                user_created = $set.user_created
                poster_id    = $poster.id
                type         = $type
                date_created = $set.date_created
                date_updated = $set.date_updated
            }
        }
    }

    foreach ($p in $show.posters) {
        Add-SetEntry -poster $p -set $p.show_set -type "poster"
    }

    foreach ($b in $show.backdrops) {
        Add-SetEntry -poster $b -set $b.show_set -type "backdrop"
    }

    foreach ($s in $show.seasons) {
        foreach ($p in $s.posters) {
            if ($p.show_set -and $p.id) {
                $allSeasonPosters += @{
                    id     = $p.id
                    season = $s.season_number
                    set_id = $p.show_set.id
                }
            }
            Add-SetEntry -poster $p -set $p.show_set -type "season_poster"
        }

        foreach ($e in $s.episodes) {
            foreach ($t in $e.titlecards) {
                if ($t.show_set -and $t.id) {
                    $allTitleCards += @{
                        id      = $t.id
                        season  = $s.season_number
                        episode = $e.episode_number
                        set_id  = $t.show_set.id
                    }
                }
                Add-SetEntry -poster $t -set $t.show_set -type "titlecard"
            }
        }
    }

    $sets = $setMap.Values

    foreach ($preferredUsername in $preferredUsernames) {
        $userSets = $sets | Where-Object { $_.user_created.username -eq $preferredUsername }
        Write-Host "[DBG] Found $($userSets.Count) show sets by '$preferredUsername'"

        $selected = $null
        if ($cleanVersion) {
            $selected = $userSets | Where-Object { $_.set_title.ToLower() -eq "clean version" } | Select-Object -First 1
        }
        if (-not $selected) {
            $expectedSet = "$title ($year) Set".ToLower()
            $selected = $userSets | Where-Object { $_.set_title.ToLower() -eq $expectedSet } | Select-Object -First 1
        }
        if (-not $selected) {
            $partialTitle = $title.ToLower()
            $selected = $userSets | Where-Object { $_.set_title.ToLower() -like "*$partialTitle*" } | Select-Object -First 1
        }
        if (-not $selected) {
            $cleanBase = (Get-CleanTitle -title $title).ToLower()
            $selected = $userSets | Where-Object { $_.set_title.ToLower() -like "*$cleanBase*" } | Select-Object -First 1
        }

        if ($selected) {
            return @{
                setId         = $selected.id
                assetId       = $selected.poster_id
                assetUrl      = "https://api.mediux.pro/assets/$($selected.poster_id)"
                seasonPosters = $allSeasonPosters | Where-Object { $_.set_id -eq $selected.id }
                titleCards    = $allTitleCards    | Where-Object { $_.set_id -eq $selected.id }
            }
        }
    }

    Write-Warning "[WRN] No matching show set found for TMDB ID $tmdbId"
    return $null
}
