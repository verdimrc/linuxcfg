Option Explicit

Dim shell
Dim fileSystem
Dim scriptDirectory
Dim powershellScript
Dim powershellExe
Dim command

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
powershellScript = fileSystem.BuildPath( _
    scriptDirectory, _
    "komorebi_mouse_spawn.ps1" _
)

powershellExe = shell.ExpandEnvironmentStrings( _
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" _
)

command = Chr(34) & powershellExe & Chr(34) _
    & " -NoLogo" _
    & " -NoProfile" _
    & " -NonInteractive" _
    & " -WindowStyle Hidden" _
    & " -ExecutionPolicy Bypass" _
    & " -File " & Chr(34) & powershellScript & Chr(34)

' 0     = hidden window
' False = do not wait for PowerShell to exit
shell.Run command, 0, False
