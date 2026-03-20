# Build and deploy to Firebase hosting (goodwin-staging)
# Usage: .\build-and-deploy-goodwin-staging.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Building Flutter web..." -ForegroundColor Cyan
flutter build web
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Clearing hosting target staging..." -ForegroundColor Cyan
firebase target:clear hosting staging
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Applying hosting target staging -> goodwin-neyvo-staging..." -ForegroundColor Cyan
firebase target:apply hosting staging goodwin-neyvo-staging
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Deploying to hosting:staging..." -ForegroundColor Cyan
firebase deploy --only hosting:staging
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Done." -ForegroundColor Green
