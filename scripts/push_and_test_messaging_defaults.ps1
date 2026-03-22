# Runs GU_Neyvo_Back/scripts/push_and_test_messaging_defaults.py (same folder layout as this repo).
# Usage from GU_Neyvo_Front:
#   .\scripts\push_and_test_messaging_defaults.ps1 -BaseUrl "https://neyvoub-back.onrender.com" -CrudOnly

param(
    [string] $BaseUrl = "http://127.0.0.1:8000",
    [switch] $CrudOnly,
    [switch] $TestTools,
    [switch] $DryRun
)

$ErrorActionPreference = "Stop"
$scriptsDir = $PSScriptRoot
$frontRoot = Split-Path $scriptsDir -Parent
$neyvoGu = Split-Path $frontRoot -Parent
$pyScript = Join-Path $neyvoGu "GU_Neyvo_Back\scripts\push_and_test_messaging_defaults.py"

if (-not (Test-Path -LiteralPath $pyScript)) {
    Write-Error "Backend script not found: $pyScript`nEnsure GU_Neyvo_Back is next to GU_Neyvo_Front under $neyvoGu"
}

$py = "python"
if (-not (Get-Command $py -ErrorAction SilentlyContinue)) { $py = "py" }

$args = @($pyScript, "--base-url", $BaseUrl)
if ($CrudOnly) { $args += "--crud-only" }
if ($TestTools) { $args += "--test-tools" }
if ($DryRun) { $args += "--dry-run" }

& $py @args
exit $LASTEXITCODE
