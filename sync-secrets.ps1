param()
# Reads C:\Users\nguye\.config\fg-collectlabs\secrets.json and pushes
# secrets to the FG-CollectLabs GitHub org so all repos pick them up.
# Usage: .\sync-secrets.ps1

$configFile = "$env:USERPROFILE\.config\fg-collectlabs\secrets.json"

if (-not (Test-Path $configFile)) {
    Write-Error "Not found: $configFile"
    exit 1
}

$cfg = Get-Content $configFile -Raw | ConvertFrom-Json

function Push-Secret {
    param([string]$Name, [string]$Value)
    if (-not $Value) {
        Write-Warning "Skipping $Name - empty in secrets.json"
        return
    }
    Write-Host "Setting $Name..." -NoNewline
    $Value | gh secret set $Name --org FG-CollectLabs
    if ($LASTEXITCODE -eq 0) { Write-Host " OK" } else { Write-Host " FAILED" }
}

Push-Secret "DOCKERHUB_TOKEN" $cfg.dockerhub_token

Write-Host "Done - org secrets set for FG-CollectLabs."
