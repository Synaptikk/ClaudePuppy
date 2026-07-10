@echo off
:: claude.cmd (VDI variant)
:: Sets HOME / USERPROFILE to the Code Puppy H:\ home before delegating to
:: claude-wrapper.ps1, mirroring Code Puppy's launcher convention so Claude
:: Code reads its config from H:\<user>\code-puppy-home\.claude\ instead of
:: the FSLogix-mangled C:\Users\<user>\.
::
:: This file lives at H:\<user>\.local\bin\claude.cmd and depends on Code
:: Puppy having already added that directory to PATH ahead of any other
:: claude.exe.
set HOMEDRIVE=H:
set HOMEPATH=\%USERNAME%\code-puppy-home
set HOME=H:\%USERNAME%\code-puppy-home
set USERPROFILE=H:\%USERNAME%\code-puppy-home
set XDG_CONFIG_HOME=H:\%USERNAME%\code-puppy-home\config
set XDG_DATA_HOME=H:\%USERNAME%\code-puppy-home\data
set XDG_CACHE_HOME=H:\%USERNAME%\code-puppy-home\cache
:: ── Fix: ensure localhost requests bypass the corporate proxy ──
:: Claude Code sends API requests to http://127.0.0.1:8787 (the local
:: sanitizer proxy). Without this, HTTP_PROXY routes those through
:: sysproxy.wal-mart.com which cannot reach the VDI's loopback —
:: causing multi-minute hangs or timeouts.
set NO_PROXY=127.0.0.1,localhost,%NO_PROXY%
powershell -NoProfile -ExecutionPolicy Bypass -File "H:\%USERNAME%\.local\bin\claude-wrapper.ps1" %*
