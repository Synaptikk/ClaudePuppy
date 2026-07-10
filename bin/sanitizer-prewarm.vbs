' sanitizer-prewarm.vbs
' Runs sanitizer-launcher.cmd hidden at Windows logon so the uv-download
' portion of the first sanitizer start (~30-60s after a VDI C:\cp_venvs
' wipe) happens before the user opens Claude Code.
'
' If the sanitizer is already running on 127.0.0.1:8787, sanitizer-launcher
' will fail to bind the port and exit fast - safe no-op.
'
' Registered in HKCU\Software\Microsoft\Windows\CurrentVersion\Run as
'   ClaudeSanitizerPrewarm = wscript.exe "H:\<user>\.local\bin\sanitizer-prewarm.vbs"

Set WshShell = CreateObject("WScript.Shell")
username = WshShell.ExpandEnvironmentStrings("%USERNAME%")
cmdLine = "cmd /c """ & "H:\" & username & "\.local\bin\sanitizer-launcher.cmd" & """"
WshShell.Run cmdLine, 0, False
