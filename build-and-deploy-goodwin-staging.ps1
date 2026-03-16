# Build and deploy to Firebase hosting (goodwin-staging)
# Usage: .\build-and-deploy-goodwin-staging.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Building Flutter web..." -ForegroundColor Cyan
flutter build web
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Clearing hosting target goodwin-staging..." -ForegroundColor Cyan
firebase target:clear hosting goodwin-staging
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Applying hosting target goodwin-staging -> goodwin-neyvo-staging..." -ForegroundColor Cyan
firebase target:apply hosting goodwin-staging goodwin-neyvo-staging
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Deploying to hosting:goodwin-staging..." -ForegroundColor Cyan
firebase deploy --only hosting:goodwin-staging
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Done." -ForegroundColor Green
