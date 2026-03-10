# Run from UB_Neyvo_Front so THIS folder becomes the git repo (not the UB_Neyvo_front subfolder).
# Usage: .\scripts\init_git_here.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

if (Test-Path ".git") {
    Write-Host "This folder is already a git repo. Add remote if needed: git remote add origin <url>" -ForegroundColor Yellow
    exit 0
}

Write-Host "Initializing git in: $root" -ForegroundColor Cyan
git init
git remote add origin https://github.com/tunkashwinraj/UB_Neyvo_front.git
git branch -M main
git add .
git status --short | Select-Object -First 5
Write-Host "Commit and push? Run: git commit -m 'Initial commit'; git push -u origin main" -ForegroundColor Yellow
Write-Host "If remote already has history, you may need: git pull origin main --allow-unrelated-histories" -ForegroundColor Gray
