# install-vdi-perf-patch.ps1
# Applies the VDI performance + self-heal patch on top of an already-installed
# ClaudePuppy VDI setup.
#
# Prerequisites (from the base setup_windows_vdi.txt installer):
#   H:\<user>\code-puppy-home\      exists
#   H:\<user>\.local\bin\           exists and is on PATH
#   H:\<user>\.local\bin\claude-real.exe present
#   Code Puppy authenticated once (puppy.cfg exists)
#
# What this patch does (all idempotent - safe to re-run):
#   1. Deploys the modified/new launcher files to H:\<user>\.local\bin\
#   2. Repoints .claude\settings.json apiKeyHelper at %LOCALAPPDATA%\ClaudePuppy\
#      (the SMB batch load was the actual bottleneck, not the puppy.cfg read)
#   3. Seeds the token cache file so the fast path works before the wrapper
#      has run for the first time
#   4. Copies setup_windows_vdi.txt (rename to .ps1) into H:\<user>\.local\bin\
#      so ensure-code-puppy.ps1 has an installer to invoke after a wipe
#   5. Registers the two HKCU Run entries (sanitizer prewarm + code-puppy ensure)
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File install-vdi-perf-patch.ps1
#
# Optional param: -InstallerSource points at where setup_windows_vdi.txt lives
# (default: %USERPROFILE%\Downloads\setup_windows_vdi.txt).

param(
    [string]$InstallerSource = $null
)

$ErrorActionPreference = "Stop"

$username    = $env:USERNAME
$userBin     = "H:\$username\.local\bin"
$puppyHome   = "H:\$username\code-puppy-home"
$puppyCfg    = "$puppyHome\config\code_puppy\puppy.cfg"
$settingsPs  = "$puppyHome\.claude\settings.json"
$cacheDir    = Join-Path $env:LOCALAPPDATA 'ClaudePuppy'
$cacheFile   = Join-Path $cacheDir 'puppy_token.txt'
$localHelper = Join-Path $cacheDir 'get-puppy-token.cmd'

Write-Host ""
Write-Host "  ClaudePuppy VDI Perf + Self-Heal Patch" -ForegroundColor Cyan
Write-Host "  User: $username" -ForegroundColor Gray
Write-Host ""

# --- 0. Sanity ------------------------------------------------------------
if (-not (Test-Path $userBin))     { throw "Missing $userBin - run the base VDI installer first." }
if (-not (Test-Path "$userBin\claude-real.exe")) { throw "Missing $userBin\claude-real.exe - run the base VDI installer first." }
if (-not (Test-Path $puppyCfg))    { throw "Missing $puppyCfg - launch Code Puppy once to authenticate." }
if (-not (Test-Path $settingsPs))  { throw "Missing $settingsPs - the base VDI installer should have created it." }

# --- 1. Deploy launcher files --------------------------------------------
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$binSrc   = Join-Path $repoRoot 'bin'
if (-not (Test-Path $binSrc)) { throw "Missing $binSrc - are you running this from the repo root?" }

$deployFiles = @(
    'claude.cmd',
    'claude-wrapper.ps1',
    'get-puppy-token.cmd',
    'sanitizer-launcher.cmd',
    'sanitizer-prewarm.vbs',
    'code-puppy-prewarm.vbs',
    'ensure-code-puppy.ps1',
    'register-run-keys.ps1'
)
foreach ($f in $deployFiles) {
    Copy-Item -Path (Join-Path $binSrc $f) -Destination (Join-Path $userBin $f) -Force
    Write-Host "[OK] deployed $f" -ForegroundColor Green
}

# --- 2. Repoint apiKeyHelper in settings.json ----------------------------
$settings = Get-Content $settingsPs -Raw | ConvertFrom-Json
if ($settings.apiKeyHelper -ne $localHelper) {
    $settings.apiKeyHelper = $localHelper
    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPs -Encoding UTF8
    Write-Host "[OK] apiKeyHelper -> $localHelper" -ForegroundColor Green
} else {
    Write-Host "[SKIP] apiKeyHelper already points at C:\ helper" -ForegroundColor Gray
}

# --- 3. Seed token cache + local helper (so it works before first wrapper launch)
if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
$cfg   = Get-Content $puppyCfg -Raw
$token = [regex]::Match($cfg, 'puppy_token\s*=\s*(\S+)').Groups[1].Value
if (-not $token) { throw "No puppy_token in $puppyCfg" }
[System.IO.File]::WriteAllText($cacheFile, $token + "`r`n")
Write-Host "[OK] seeded token cache ($((Get-Item $cacheFile).Length) bytes)" -ForegroundColor Green

Copy-Item -Path (Join-Path $binSrc 'get-puppy-token.cmd') -Destination $localHelper -Force
Write-Host "[OK] deployed local helper -> $localHelper" -ForegroundColor Green

# --- 4. Copy setup_windows_vdi.txt into H:\ as setup-code-puppy.ps1 ------
$installerDst = Join-Path $userBin 'setup-code-puppy.ps1'
if (-not $InstallerSource) {
    $InstallerSource = Join-Path $env:USERPROFILE 'Downloads\setup_windows_vdi.txt'
}
if (Test-Path $InstallerSource) {
    Copy-Item -Path $InstallerSource -Destination $installerDst -Force
    Write-Host "[OK] setup-code-puppy.ps1 <- $InstallerSource" -ForegroundColor Green
} elseif (Test-Path $installerDst) {
    Write-Host "[SKIP] setup-code-puppy.ps1 already deployed (source $InstallerSource not found)" -ForegroundColor Gray
} else {
    Write-Warning "Installer source not found ($InstallerSource) and no existing copy at $installerDst - ensure-code-puppy.ps1 will not be able to self-heal until you drop it in."
}

# --- 5. Register HKCU Run entries ----------------------------------------
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $userBin 'register-run-keys.ps1')

Write-Host ""
Write-Host "[SUCCESS] Patch applied." -ForegroundColor Green
Write-Host "  Restart your terminal, then run: claude" -ForegroundColor White
Write-Host ""
