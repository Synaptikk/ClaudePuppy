# claudepuppy-vdi-perf

Performance + self-heal patch for the [ClaudePuppy](https://github.com/) VDI
setup running against the Walmart LLM Gateway. Cuts per-API-call auth overhead
by ~15x and auto-recovers from the weekly `C:\cp_venvs\<user>\` wipe.

## Problems this fixes

Running Claude Code on the Walmart VDI has two chronic pain points that
compound each other:

1. **~870 ms of overhead on every API call.** The base ClaudePuppy install
   points Claude Code's `apiKeyHelper` at `H:\<user>\.local\bin\get-puppy-token.cmd`.
   `H:\` is a network SMB share. `cmd.exe` has to load the batch file from the
   share on every invocation, and Claude Code invokes `apiKeyHelper` on every
   `/v1/messages` request. A single conversation turn easily makes 10+ API
   calls, so this adds **5-13 seconds of pure wait per turn**.

2. **The weekly VDI wipe blows away Code Puppy.** `C:\cp_venvs\<user>\` is
   local-disk and gets wiped by VDI imaging weekly. `claude-real.exe` (on
   `H:\`) still works, but Code Puppy — which is what refreshes the JWT that
   Claude Code uses to auth — can't run until someone manually re-runs the
   installer.

## What this patch does

| Fix | Before | After |
|---|---|---|
| Move `get-puppy-token.cmd` to `%LOCALAPPDATA%\ClaudePuppy\` | ~870 ms / call | **~55 ms / call** (15.8x faster) |
| Cache `puppy_token` to `%LOCALAPPDATA%\ClaudePuppy\puppy_token.txt` | SMB `findstr` on `puppy.cfg` per call | Local `type` per call |
| Auto-refresh token cache | Manual | `claude-wrapper.ps1` rewrites cache on every launch (picks up rotations) |
| Sanitizer prewarm at logon | ~30-60 s stall on first `claude` after wipe | Sanitizer up before you open a terminal |
| Code Puppy self-heal after wipe | Manual re-run of `setup_windows_vdi.txt` | `ensure-code-puppy.ps1` fires at logon; no-op when venv is present |

## Layout

```
claudepuppy-vdi-perf/
├── bin/
│   ├── claude.cmd                       # unchanged from base installer
│   ├── claude-wrapper.ps1               # MODIFIED: writes token cache + local helper + migrates apiKeyHelper path
│   ├── get-puppy-token.cmd              # MODIFIED: cache-first fast path, fallback to H:\ findstr
│   ├── sanitizer-launcher.cmd           # unchanged
│   ├── sanitizer-prewarm.vbs            # NEW: hidden shim for HKCU\...\Run
│   ├── code-puppy-prewarm.vbs           # NEW: hidden shim for HKCU\...\Run
│   ├── ensure-code-puppy.ps1            # NEW: fast-path guard, invokes setup-code-puppy.ps1 if venv missing
│   └── register-run-keys.ps1            # NEW: idempotent HKCU Run key registration
├── install-vdi-perf-patch.ps1           # NEW: one-shot idempotent patch installer
├── CHANGES.md                            # detailed rundown of what changed and why
└── README.md                             # this file
```

## Prerequisites

- Base `setup_windows_vdi.txt` (Code Puppy VDI installer v9+) has run at
  least once, so `H:\<user>\code-puppy-home\`, `H:\<user>\.local\bin\`,
  `claude-real.exe`, and `puppy.cfg` are all in place.
- You have `setup_windows_vdi.txt` in `%USERPROFILE%\Downloads\` (or pass its
  path with `-InstallerSource`).

## Install

```powershell
git clone https://github.com/synaptikk/<repo>.git
cd <repo>
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-vdi-perf-patch.ps1
```

Restart your terminal, then `claude`. That's it.

## Verify the fix

```powershell
# Time the token helper - should be ~50-80ms/call
Measure-Command { 1..10 | ForEach-Object { & "$env:LOCALAPPDATA\ClaudePuppy\get-puppy-token.cmd" | Out-Null } }

# Confirm apiKeyHelper is repointed
(Get-Content "H:\$env:USERNAME\code-puppy-home\.claude\settings.json" | ConvertFrom-Json).apiKeyHelper

# Confirm HKCU Run entries are registered
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" | Select-String Claude
```

## Uninstall

```powershell
# Restore original apiKeyHelper
$settings = Get-Content "H:\$env:USERNAME\code-puppy-home\.claude\settings.json" -Raw | ConvertFrom-Json
$settings.apiKeyHelper = "H:\$env:USERNAME\.local\bin\get-puppy-token.cmd"
$settings | ConvertTo-Json -Depth 10 | Set-Content "H:\$env:USERNAME\code-puppy-home\.claude\settings.json" -Encoding UTF8

# Remove HKCU Run entries
Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name ClaudeSanitizerPrewarm -ErrorAction SilentlyContinue
Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name ClaudePuppyEnsure -ErrorAction SilentlyContinue

# Remove cache dir (optional)
Remove-Item -Recurse "$env:LOCALAPPDATA\ClaudePuppy"
```

## Not fixed by this patch

- **First-run sanitizer install after a full wipe still takes 30-60 s.** The
  prewarm just hides it from your interactive experience. If you skip the
  prewarm (e.g. cold boot straight into `claude`), you'll still see the
  `[claude-wrapper] Starting sanitizer proxy in background...` wait.
- **Code Puppy reinstall still takes 2-5 min after a wipe.** Prewarm runs it
  in the background at logon; if you open `claude` first it'll still work
  (as long as your JWT hasn't expired), but Code Puppy itself won't launch
  until the ensure script finishes.
- **JWT expiry.** `puppy_token` JWTs are typically valid for weeks. When they
  expire, you still need to run `code-puppy` interactively to refresh. This
  patch surfaces the warning earlier (via `claude-wrapper.ps1`) but doesn't
  automate the refresh.
