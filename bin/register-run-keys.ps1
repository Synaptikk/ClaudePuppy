# register-run-keys.ps1
# Idempotently register the two HKCU\...\Run entries that pre-warm both:
#   - the sanitizer proxy (survives fine; just prewarmed to hide the first-run
#     uv download after a wipe)
#   - the Code Puppy venv (self-heals after the weekly C:\cp_venvs wipe)
#
# Safe to re-run any time; overwrites existing entries with the current values.

$ErrorActionPreference = "Stop"

$username = $env:USERNAME
$userBin  = "H:\$username\.local\bin"

$entries = @(
    @{
        Name  = 'ClaudeSanitizerPrewarm'
        Value = "wscript.exe `"$userBin\sanitizer-prewarm.vbs`""
        Vbs   = "$userBin\sanitizer-prewarm.vbs"
    },
    @{
        Name  = 'ClaudePuppyEnsure'
        Value = "wscript.exe `"$userBin\code-puppy-prewarm.vbs`""
        Vbs   = "$userBin\code-puppy-prewarm.vbs"
    }
)

$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

foreach ($e in $entries) {
    if (-not (Test-Path $e.Vbs)) {
        Write-Warning "Skipping $($e.Name): $($e.Vbs) does not exist yet. Deploy the .vbs first."
        continue
    }
    New-ItemProperty -Path $regPath -Name $e.Name -Value $e.Value -PropertyType String -Force | Out-Null
    Write-Host "[OK] $($e.Name) -> $($e.Value)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Verify with: reg query `"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`"" -ForegroundColor Cyan
