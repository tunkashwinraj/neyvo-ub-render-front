# encode_firebase_credentials.ps1
# Convert Firebase service account JSON to Base64 for Render

param(
    [string]$Path = "google-credentials.json",
    [switch]$Help
)

if ($Help) {
    Write-Host @"

Firebase Credentials Encoder
============================

Converts your Firebase service account JSON to base64 for Render.

Usage:
    .\encode_firebase_credentials.ps1 [-Path <path>]

Options:
    -Path     Path to credentials file (default: google-credentials.json)
    -Help     Show this help message

After running:
    1. Copy the base64 string (it's also copied to clipboard)
    2. In Render: set FIREBASE_CREDENTIALS_BASE64="<paste full base64>"

"@
    exit 0
}

if (-not (Test-Path $Path)) {
    Write-Host "[ERROR] File not found: $Path" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common filenames:"
    Write-Host "  - google-credentials.json"
    Write-Host "  - firebase-credentials.json"
    Write-Host "  - service-account.json"
    Write-Host ""
    Write-Host "Download from: Firebase Console > Project Settings > Service Accounts" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  Firebase Credentials Encoder for Render" -ForegroundColor White
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Reading credentials file: $Path" -ForegroundColor Yellow
try {
    $content = Get-Content -Raw -Path $Path
    $json = $content | ConvertFrom-Json

    if (-not $json.type -or $json.type -ne "service_account") {
        Write-Host "[WARN] This doesn't look like a service account file" -ForegroundColor Yellow
    }

    Write-Host "  Project ID : $($json.project_id)" -ForegroundColor Gray
    Write-Host "  Client Email: $($json.client_email)" -ForegroundColor Gray
} catch {
    Write-Host "[ERROR] Invalid JSON file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "[2/4] Encoding to base64..." -ForegroundColor Yellow
$bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
$base64 = [Convert]::ToBase64String($bytes)

Write-Host "[3/4] Copying to clipboard..." -ForegroundColor Yellow
try {
    $base64 | Set-Clipboard
    Write-Host "  [OK] Copied to clipboard!" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Could not copy to clipboard" -ForegroundColor Yellow
}

Write-Host "[4/4] Base64 encoded credentials (preview):" -ForegroundColor Yellow
Write-Host ""
$preview = $base64.Substring(0, [Math]::Min(60, $base64.Length))
$suffix = if ($base64.Length -gt 120) { "..." + $base64.Substring($base64.Length - 30) } else { "" }
Write-Host "  $preview$suffix" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total length: $($base64.Length) characters" -ForegroundColor Gray
Write-Host ""

Write-Host ("=" * 60) -ForegroundColor Green
Write-Host "  NEXT STEPS (Render)" -ForegroundColor White
Write-Host ("=" * 60) -ForegroundColor Green
Write-Host @"

1. Render Dashboard → Your Service → Environment
2. Add variable: FIREBASE_CREDENTIALS_BASE64
3. Paste the FULL base64 string (not just the preview)
4. Save changes and redeploy

SECURITY NOTE: Never commit this base64 string or JSON file to git.

"@

