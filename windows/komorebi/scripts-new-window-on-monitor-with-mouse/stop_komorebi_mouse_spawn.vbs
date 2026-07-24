Option Explicit

Const HIDDEN_WINDOW = 0
Const WAIT_FOR_COMMAND = True
Const STOP_TIMEOUT_MS = 20000
Const POLL_INTERVAL_MS = 100

Dim shell
Dim fileSystem
Dim scriptDirectory
Dim targetScript
Dim targetScriptLower
Dim komorebicExe
Dim wmiService
Dim processes
Dim process
Dim commandLine
Dim processId
Dim pipeName
Dim unsubscribeCommand
Dim unsubscribeExitCode
Dim waitedMilliseconds
Dim foundCount
Dim stoppedCount
Dim forcedCount
Dim failedCount
Dim terminateResult

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
targetScript = fileSystem.BuildPath(scriptDirectory, "komorebi_mouse_spawn.ps1")
targetScriptLower = LCase(targetScript)

komorebicExe = shell.ExpandEnvironmentStrings( _
    "%ProgramFiles%\komorebi\bin\komorebic.exe" _
)

If Not fileSystem.FileExists(komorebicExe) Then
    komorebicExe = "komorebic.exe"
End If

Set wmiService = GetObject( _
    "winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2" _
)

Set processes = wmiService.ExecQuery( _
    "SELECT ProcessId, Name, CommandLine " & _
    "FROM Win32_Process " & _
    "WHERE Name='powershell.exe' OR Name='pwsh.exe'" _
)

foundCount = 0
stoppedCount = 0
forcedCount = 0
failedCount = 0

For Each process In processes
    commandLine = ""

    If Not IsNull(process.CommandLine) Then
        commandLine = CStr(process.CommandLine)
    End If

    If InStr(1, LCase(commandLine), targetScriptLower, vbTextCompare) > 0 Then
        foundCount = foundCount + 1
        processId = CLng(process.ProcessId)
        pipeName = "komorebi_mouse_spawner_" & CStr(processId)

        ' Removing the subscription closes komorebi's end of the named pipe.
        ' The PowerShell subscriber then leaves its read loop normally, so its
        ' finally block can restore mouse-follows-focus and clean up the mutex.
        unsubscribeCommand = Quote(komorebicExe) & _
            " unsubscribe-pipe " & Quote(pipeName)

        On Error Resume Next
        Err.Clear

        unsubscribeExitCode = shell.Run( _
            unsubscribeCommand, _
            HIDDEN_WINDOW, _
            WAIT_FOR_COMMAND _
        )

        If Err.Number <> 0 Then
            unsubscribeExitCode = -1
            Err.Clear
        End If

        On Error GoTo 0

        waitedMilliseconds = 0

        Do While ProcessExists(wmiService, processId) _
            And waitedMilliseconds < STOP_TIMEOUT_MS

            WScript.Sleep POLL_INTERVAL_MS
            waitedMilliseconds = waitedMilliseconds + POLL_INTERVAL_MS
        Loop

        If Not ProcessExists(wmiService, processId) Then
            stoppedCount = stoppedCount + 1
        Else
            ' Last-resort fallback. This bypasses the PowerShell finally block,
            ' so it should only be reached if graceful pipe shutdown failed.
            terminateResult = -1

            On Error Resume Next
            Err.Clear

            terminateResult = process.Terminate()

            If Err.Number <> 0 Then
                terminateResult = -1
                Err.Clear
            End If

            On Error GoTo 0

            WScript.Sleep 500

            If Not ProcessExists(wmiService, processId) Then
                forcedCount = forcedCount + 1
            Else
                failedCount = failedCount + 1
            End If
        End If
    End If
Next

If foundCount = 0 Then
    MsgBox _
        "No running komorebi_mouse_spawn.ps1 subscriber was found.", _
        vbInformation, _
        "Komorebi mouse spawner"
ElseIf failedCount > 0 Then
    MsgBox _
        "The stop request could not terminate " & CStr(failedCount) & _
        " subscriber process(es)." & vbCrLf & vbCrLf & _
        "Try Task Manager, then restore mouse-follows-focus manually if needed:" & _
        vbCrLf & "komorebic mouse-follows-focus enable", _
        vbExclamation, _
        "Komorebi mouse spawner"
ElseIf forcedCount > 0 Then
    MsgBox _
        "The subscriber did not exit after its named pipe was closed, so " & _
        CStr(forcedCount) & " process(es) had to be terminated." & _
        vbCrLf & vbCrLf & _
        "Because forced termination bypasses PowerShell cleanup, restore " & _
        "mouse-follows-focus manually if it was enabled before startup:" & _
        vbCrLf & "komorebic mouse-follows-focus enable", _
        vbExclamation, _
        "Komorebi mouse spawner"
End If

Function Quote(ByVal value)
    Quote = Chr(34) & CStr(value) & Chr(34)
End Function

Function ProcessExists(ByRef service, ByVal wantedProcessId)
    Dim result

    Set result = service.ExecQuery( _
        "SELECT ProcessId FROM Win32_Process WHERE ProcessId=" & _
        CStr(wantedProcessId) _
    )

    ProcessExists = (result.Count > 0)
End Function
