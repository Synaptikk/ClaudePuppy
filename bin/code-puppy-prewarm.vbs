' code-puppy-prewarm.vbs
' Runs ensure-code-puppy.ps1 hidden at Windows logon so that a wiped
' C:\cp_venvs\<user>\code-puppy-venv gets rebuilt before the user opens
' Code Puppy or Claude Code.
'
' Fast-exits when code-puppy.exe is already present.
'
' Registered in HKCU\Software\Microsoft\Windows\CurrentVersion\Run as
'   ClaudePuppyEnsure = wscript.exe "H:\<user>\.local\bin\code-puppy-prewarm.vbs"

Set WshShell = CreateObject("WScript.Shell")
username = WshShell.ExpandEnvironmentStrings("%USERNAME%")
cmdLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & "H:\" & username & "\.local\bin\ensure-code-puppy.ps1" & """"
WshShell.Run cmdLine, 0, False
