# ensure-code-puppy.ps1
# Fast-path guard around the Code Puppy VDI installer.
#
# VDI imaging wipes C:\cp_venvs\<user>\ weekly. When that happens, code-puppy.exe
# disappears, so Code Puppy itself can no longer refresh the puppy_token used
# by Claude Code. This script:
#
#   - Fast-exits (silent, <100ms) when code-puppy.exe is present.
#   - Otherwise runs setup-code-puppy.ps1 to rebuild the venv from the
#     Walmart pypi mirror (~2-5 min the first time after a wipe).
#
# Registered in HKCU\...\Run to fire at logon and (optionally) called
# synchronously from claude.cmd so a user who launches Claude before the
# background rebuild finishes still gets a working environment.

$username     = $env:USERNAME
$venvExe      = "C:\cp_venvs\$username\code-puppy-venv\Scripts\code-puppy.exe"
$installerPs1 = "H:\$username\.local\bin\setup-code-puppy.ps1"

if (Test-Path $venvExe) { exit 0 }

if (-not (Test-Path $installerPs1)) {
    Write-Error "Code Puppy is missing from C:\cp_venvs\$username\ and the installer at $installerPs1 is not present either. Re-download setup_windows_vdi.txt into H:\$username\.local\bin\setup-code-puppy.ps1."
    exit 1
}

Write-Host "[ensure-code-puppy] C:\cp_venvs\$username\ appears wiped. Reinstalling Code Puppy..." -ForegroundColor Yellow
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installerPs1
exit $LASTEXITCODE
