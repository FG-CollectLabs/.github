# Reads C:\Users\nguye\.config\fg-collectlabs\secrets.json and pushes
# secrets to the FG-CollectLabs GitHub org so all repos pick them up.
#
# Usage: .\sync-secrets.ps1
# Run after editing secrets.json with real values.

$configFile = "$env:USERPROFILE\.config\fg-collectlabs\secrets.json"

if (-not (Test-Path $configFile)) {
    Write-Error "Config file not found: $configFile"
    exit 1
}

$secrets = Get-Content $configFile -Raw | ConvertFrom-Json

function Set-OrgSecret {
    param([string]$Name, [string]$Value)
    if (-not $Value) {
        Write-Warning "Skipping $Name — value is empty in secrets.json"
        return
    }
    Write-Host "Setting org secret: $Name" -ForegroundColor Cyan
    $Value | gh secret set $Name --org FG-CollectLabs
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK" -ForegroundColor Green
    } else {
        Write-Warning "  Failed (exit $LASTEXITCODE)"
    }
}

Set-OrgSecret "DOCKERHUB_TOKEN" $secrets.dockerhub_token

Write-Host ""
Write-Host "Done. Org secrets are available to all FG-CollectLabs repos." -ForegroundColor Green
