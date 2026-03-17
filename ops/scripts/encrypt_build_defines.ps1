param(
  [Parameter(Mandatory=$true)]
  [string]$AgePublicKeyPath,

  [Parameter(Mandatory=$true)]
  [string]$PlainJsonPath,

  [Parameter(Mandatory=$false)]
  [string]$OutEncPath = "ops/secrets/frontend-build-defines.json.enc"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $AgePublicKeyPath)) { throw "Missing age public key: $AgePublicKeyPath" }
if (!(Test-Path $PlainJsonPath)) { throw "Missing plaintext JSON file: $PlainJsonPath" }

$agePub = (Get-Content -Raw $AgePublicKeyPath).Trim()
if ($agePub.Length -lt 10) { throw "Age public key looks invalid." }

Write-Host "Encrypting $PlainJsonPath -> $OutEncPath"

# Requires: sops in PATH
sops --encrypt --age $agePub $PlainJsonPath | Out-File -Encoding utf8 $OutEncPath

Write-Host "Done. Do NOT commit plaintext file."

