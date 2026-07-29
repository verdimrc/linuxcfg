# HAHA: Created with Codex (Pro)

# C:\Users\Public\yasb-scripts\komorebi-container-mode.ps1

# YASB will decode this script's output as UTF-8.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

function Write-WidgetJson {
    param(
        [string]$Indicator,
        [string]$Mode,
        [string]$Raw,
        [string]$Tooltip
    )

    [pscustomobject]@{
        indicator = $Indicator
        mode      = $Mode
        raw       = $Raw
        tooltip   = $Tooltip
    } | ConvertTo-Json -Compress
}

try {
    $komorebic = (
        Get-Command "komorebic.exe" `
            -CommandType Application `
            -ErrorAction Stop |
        Select-Object -First 1
    ).Source

    $stateText = (& $komorebic state 2>$null | Out-String)

    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($stateText)
    ) {
        throw "komorebic.exe state returned no usable data."
    }

    $state = $stateText | ConvertFrom-Json
    $behaviour = [string]$state.new_window_behaviour

    ## HAHA: glyphs (but need ?? fonts??): ▣ (Stack), ▦ (Append), × (Unknown or off)

    switch ($behaviour) {
        "Append" {
            Write-WidgetJson `
                -Indicator "[S]" `
                -Mode "STACK" `
                -Raw "Append" `
                -Tooltip "New windows are appended to the focused container."
            break
        }

        "Create" {
            Write-WidgetJson `
                -Indicator "[C]" `
                -Mode "TILE" `
                -Raw "Create" `
                -Tooltip "New windows create a separate container."
            break
        }

        default {
            Write-WidgetJson `
                -Indicator "[?]" `
                -Mode "UNKNOWN" `
                -Raw $behaviour `
                -Tooltip "Unexpected Komorebi state: $behaviour"
            break
        }
    }
}
catch {
    Write-WidgetJson `
        -Indicator "[x]" `
        -Mode "OFF" `
        -Raw "Unavailable" `
        -Tooltip "Komorebi is stopped, or komorebic.exe is not available through PATH."
}
