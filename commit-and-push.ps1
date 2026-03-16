# Fix "your local changes would be overwritten by merge" and push all changes.
# Run from: UB_Neyvo_Front (repo root, not UB_Neyvo_Front\UB_Neyvo_Front)
# Usage: .\commit-and-push.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Staging lib changes..." -ForegroundColor Cyan
git add lib/main.dart lib/screens/executive_dashboard_page.dart lib/neyvo_pulse_api.dart lib/screens/pulse_shell.dart
$status = git status --short
if ($status) {
    Write-Host "Committing your changes..." -ForegroundColor Cyan
    git commit -m "Executive Dashboard: Home=dashboard, KPI /api/pulse/kpi with fallback, scrollable filters"
}
Write-Host "Pulling from origin/Testing..." -ForegroundColor Cyan
git pull origin Testing --no-edit
if ($LASTEXITCODE -ne 0) {
    Write-Host "Merge conflict. Resolve conflicts in the reported files, then: git add . ; git commit -m 'Merge' ; git push origin Testing" -ForegroundColor Yellow
    exit 1
}
Write-Host "Pushing to origin/Testing..." -ForegroundColor Cyan
git push origin Testing
Write-Host "Done." -ForegroundColor Green
