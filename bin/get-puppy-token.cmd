@echo off
:: get-puppy-token.cmd (VDI variant - cached fast path)
:: Claude Code invokes apiKeyHelper on every API request. Reading puppy.cfg
:: from H:\ each time cost ~870ms/call over SMB. This version reads a mirror
:: on C:\ (%LOCALAPPDATA%\ClaudePuppy\puppy_token.txt) that claude-wrapper.ps1
:: refreshes on every wrapper launch, cutting the call to ~5ms.
::
:: Fallback: if the cache file is missing (first launch, or user ran claude
:: without the wrapper), we do the original slow findstr on H:\ so auth still
:: works.
::
:: Note: `type` is used because `for /f` inside a batch adds ~1s/call, and
:: `set /p` truncates at ~1023 chars (JWTs are ~2700+).
if exist "%LOCALAPPDATA%\ClaudePuppy\puppy_token.txt" (
    type "%LOCALAPPDATA%\ClaudePuppy\puppy_token.txt"
    exit /b 0
)
for /f "tokens=2 delims== " %%a in ('findstr /b "puppy_token" "H:\%USERNAME%\code-puppy-home\config\code_puppy\puppy.cfg"') do @echo %%a
