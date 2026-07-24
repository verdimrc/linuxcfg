#requires -version 5.1

<#
.SYNOPSIS
Moves each newly managed komorebi window to the monitor containing the mouse pointer.

.DESCRIPTION
This script hosts the Windows named pipe that komorebi writes subscription events to.
It tracks window handles so that Show/Uncloak events for existing windows are ignored,
and it continuously drains the pipe on a background .NET thread so commands issued by
this script cannot deadlock komorebi's notification writer.

Run one instance only. Stop it with Ctrl+C.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Komorebic = "komorebic.exe",

    [Parameter()]
    [ValidateRange(250, 10000)]
    [int]$FocusTimeoutMilliseconds = 1500,

    [Parameter()]
    [ValidateRange(250, 10000)]
    [int]$MoveVerificationTimeoutMilliseconds = 1500,

    [Parameter()]
    [ValidateSet("Error", "Warn", "Info", "Debug", "Trace")]
    [string]$LogLevel = "Debug",

    [Parameter()]
    [switch]$LogRawNotifications,

    [Parameter()]
    [switch]$KeepMouseFollowsFocus
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:LogLevelOrder = @{
    Error = 0
    Warn  = 1
    Info  = 2
    Debug = 3
    Trace = 4
}
$script:ConfiguredLogLevel = $LogLevel
$script:LogSessionId = [Guid]::NewGuid().ToString("N").Substring(0, 12)
$script:LogSequence = [Int64]0
$script:StateQueryCount = [Int64]0

function Limit-DiagnosticText {
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Text,

        [Parameter()]
        [ValidateRange(64, 1048576)]
        [int]$MaximumLength = 4096
    )

    if ($null -eq $Text) {
        return $null
    }

    $value = [string]$Text
    if ($value.Length -le $MaximumLength) {
        return $value
    }

    return $value.Substring(0, $MaximumLength) + "...[truncated; original_length=$($value.Length)]"
}

function Write-Diagnostic {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Error", "Warn", "Info", "Debug", "Trace")]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Event,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Message = "",

        [Parameter()]
        [AllowNull()]
        [System.Collections.IDictionary]$Data
    )

    try {
        if ($script:LogLevelOrder[$Level] -gt $script:LogLevelOrder[$script:ConfiguredLogLevel]) {
            return
        }

        $script:LogSequence = $script:LogSequence + 1

        $record = [ordered]@{
            timestamp_utc = [DateTime]::UtcNow.ToString(
                "o",
                [System.Globalization.CultureInfo]::InvariantCulture
            )
            level         = $Level.ToUpperInvariant()
            session       = $script:LogSessionId
            pid           = $PID
            sequence      = $script:LogSequence
            event         = $Event
        }

        if (-not [string]::IsNullOrWhiteSpace($Message)) {
            $record["message"] = $Message
        }

        if ($null -ne $Data) {
            $keys = @($Data.Keys | ForEach-Object { [string]$_ } | Sort-Object)
            foreach ($key in $keys) {
                $outputKey = $key
                if ($record.Contains($outputKey)) {
                    $outputKey = "data_$key"
                }
                $record[$outputKey] = $Data[$key]
            }
        }

        try {
            $line = $record | ConvertTo-Json -Compress -Depth 12
        }
        catch {
            $line = "{0} level={1} session={2} pid={3} sequence={4} event={5} message={6}" -f `
                [DateTime]::UtcNow.ToString("o"), `
                $Level.ToUpperInvariant(), `
                $script:LogSessionId, `
                $PID, `
                $script:LogSequence, `
                $Event, `
                (Limit-DiagnosticText -Text $Message -MaximumLength 1000)
        }

        if ($Level -eq "Warn" -or $Level -eq "Error") {
            [Console]::Error.WriteLine($line)
            [Console]::Error.Flush()
        }
        else {
            [Console]::Out.WriteLine($line)
            [Console]::Out.Flush()
        }
    }
    catch {
        try {
            [Console]::Error.WriteLine(
                "diagnostic_logger_failure event={0} error={1}" -f $Event, $_.Exception.Message
            )
            [Console]::Error.Flush()
        }
        catch {
            # Logging must never terminate the subscriber.
        }
    }
}

function Write-ExceptionDiagnostic {
    param(
        [Parameter(Mandatory)]
        [string]$Event,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter()]
        [ValidateSet("Error", "Warn", "Info", "Debug", "Trace")]
        [string]$Level = "Error",

        [Parameter()]
        [AllowNull()]
        [System.Collections.IDictionary]$Data
    )

    $exceptionType = $null
    $exceptionMessage = $null
    $innerExceptionType = $null
    $innerExceptionMessage = $null

    if ($null -ne $ErrorRecord.Exception) {
        $exceptionType = $ErrorRecord.Exception.GetType().FullName
        $exceptionMessage = $ErrorRecord.Exception.Message

        if ($null -ne $ErrorRecord.Exception.InnerException) {
            $innerExceptionType = $ErrorRecord.Exception.InnerException.GetType().FullName
            $innerExceptionMessage = $ErrorRecord.Exception.InnerException.Message
        }
    }

    $details = [ordered]@{
        exception_type           = $exceptionType
        exception_message        = $exceptionMessage
        inner_exception_type     = $innerExceptionType
        inner_exception_message  = $innerExceptionMessage
        fully_qualified_error_id = $ErrorRecord.FullyQualifiedErrorId
        category_info            = [string]$ErrorRecord.CategoryInfo
        script_stack_trace       = (Limit-DiagnosticText -Text $ErrorRecord.ScriptStackTrace -MaximumLength 8192)
    }

    if ($null -ne $ErrorRecord.InvocationInfo) {
        $details["position_message"] = Limit-DiagnosticText `
            -Text $ErrorRecord.InvocationInfo.PositionMessage `
            -MaximumLength 4096
    }

    if ($null -ne $Data) {
        foreach ($key in $Data.Keys) {
            $details[[string]$key] = $Data[$key]
        }
    }

    Write-Diagnostic `
        -Level $Level `
        -Event $Event `
        -Message $exceptionMessage `
        -Data $details
}

if (-not ("KomorebiMouseSpawnerDiagnosticsV1.PipeMessagePump" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.IO;
using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace KomorebiMouseSpawnerDiagnosticsV1
{
    public static class NativeMethods
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct POINT
        {
            public int X;
            public int Y;
        }

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetPhysicalCursorPos(out POINT point);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetCursorPos(out POINT point);

        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr hwnd);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool BringWindowToTop(IntPtr hwnd);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ShowWindowAsync(IntPtr hwnd, int command);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsIconic(IntPtr hwnd);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsZoomed(IntPtr hwnd);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsWindow(IntPtr hwnd);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hwnd, IntPtr processId);

        [DllImport("kernel32.dll")]
        public static extern uint GetCurrentThreadId();

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool AttachThreadInput(uint attachThread, uint attachToThread, bool attach);
    }

    public sealed class PipeMessage
    {
        public long Sequence { get; private set; }
        public DateTime CapturedUtc { get; private set; }
        public bool CursorPositionAvailable { get; private set; }
        public bool UsedPhysicalCursorPosition { get; private set; }
        public string Line { get; private set; }
        public int CursorX { get; private set; }
        public int CursorY { get; private set; }
        public long ForegroundHwnd { get; private set; }

        public PipeMessage(
            long sequence,
            DateTime capturedUtc,
            bool cursorPositionAvailable,
            bool usedPhysicalCursorPosition,
            string line,
            int cursorX,
            int cursorY,
            long foregroundHwnd)
        {
            Sequence = sequence;
            CapturedUtc = capturedUtc;
            CursorPositionAvailable = cursorPositionAvailable;
            UsedPhysicalCursorPosition = usedPhysicalCursorPosition;
            Line = line;
            CursorX = cursorX;
            CursorY = cursorY;
            ForegroundHwnd = foregroundHwnd;
        }
    }

    public sealed class PipeMessagePump : IDisposable
    {
        private readonly NamedPipeServerStream pipe;
        private readonly Thread thread;
        private volatile bool stopping;
        private long messageSequence;

        public BlockingCollection<PipeMessage> Messages { get; private set; }
        public ManualResetEventSlim Connected { get; private set; }
        public Exception Error { get; private set; }

        public PipeMessagePump(NamedPipeServerStream pipe)
        {
            this.pipe = pipe;
            Messages = new BlockingCollection<PipeMessage>(new ConcurrentQueue<PipeMessage>());
            Connected = new ManualResetEventSlim(false);
            thread = new Thread(Pump);
            thread.IsBackground = true;
            thread.Name = "komorebi mouse-spawner pipe reader";
        }

        public void Start()
        {
            thread.Start();
        }

        private void Pump()
        {
            try
            {
                pipe.WaitForConnection();
                Connected.Set();

                using (var reader = new StreamReader(
                    pipe,
                    new UTF8Encoding(false),
                    true,
                    65536,
                    true))
                {
                    string line;
                    while (!stopping && (line = reader.ReadLine()) != null)
                    {
                        NativeMethods.POINT point;
                        bool usedPhysicalCursorPosition = NativeMethods.GetPhysicalCursorPos(out point);
                        bool cursorPositionAvailable = usedPhysicalCursorPosition;

                        if (!usedPhysicalCursorPosition)
                        {
                            cursorPositionAvailable = NativeMethods.GetCursorPos(out point);
                        }

                        long foreground = NativeMethods.GetForegroundWindow().ToInt64();
                        long sequence = Interlocked.Increment(ref messageSequence);
                        DateTime capturedUtc = DateTime.UtcNow;

                        Messages.Add(new PipeMessage(
                            sequence,
                            capturedUtc,
                            cursorPositionAvailable,
                            usedPhysicalCursorPosition,
                            line,
                            point.X,
                            point.Y,
                            foreground));
                    }
                }
            }
            catch (ObjectDisposedException)
            {
                // Expected during shutdown.
            }
            catch (IOException ex)
            {
                if (!stopping)
                {
                    Error = ex;
                }
            }
            catch (Exception ex)
            {
                if (!stopping)
                {
                    Error = ex;
                }
            }
            finally
            {
                Connected.Set();
                Messages.CompleteAdding();
            }
        }

        public void Dispose()
        {
            stopping = true;

            try { pipe.Dispose(); } catch { }

            if (thread.IsAlive && Thread.CurrentThread != thread)
            {
                thread.Join(5000);
            }

            Connected.Dispose();
            if (!thread.IsAlive)
            {
                Messages.Dispose();
            }
        }
    }
}
'@
}

function Get-RingElements {
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Ring
    )

    if ($null -eq $Ring) {
        return
    }

    $elementsProperty = $Ring.PSObject.Properties["elements"]
    if ($null -eq $elementsProperty -or $null -eq $elementsProperty.Value) {
        return
    }

    foreach ($element in @($elementsProperty.Value)) {
        Write-Output $element
    }
}

function Get-FocusedRingElement {
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Ring
    )

    $elements = @(Get-RingElements -Ring $Ring)
    if ($elements.Count -eq 0) {
        return $null
    }

    $focusedIndex = 0
    $focusedProperty = $Ring.PSObject.Properties["focused"]
    if ($null -ne $focusedProperty -and $null -ne $focusedProperty.Value) {
        $focusedIndex = [int]$focusedProperty.Value
    }

    if ($focusedIndex -lt 0 -or $focusedIndex -ge $elements.Count) {
        return $null
    }

    return $elements[$focusedIndex]
}

function Add-WindowLocation {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Map,

        [Parameter()]
        [AllowNull()]
        [object]$Window,

        [Parameter(Mandatory)]
        [int]$MonitorIndex,

        [Parameter(Mandatory)]
        [int]$WorkspaceIndex,

        [Parameter(Mandatory)]
        [string]$Kind,

        [Parameter()]
        [int]$ContainerIndex = -1,

        [Parameter()]
        [int]$ContainerWindowCount = 1
    )

    if ($null -eq $Window) {
        return
    }

    $hwndProperty = $Window.PSObject.Properties["hwnd"]
    if ($null -eq $hwndProperty -or $null -eq $hwndProperty.Value) {
        return
    }

    $hwnd = [Int64]$hwndProperty.Value
    if ($hwnd -eq 0) {
        return
    }

    $Map[[string]$hwnd] = [pscustomobject]@{
        Hwnd                 = $hwnd
        MonitorIndex         = $MonitorIndex
        WorkspaceIndex       = $WorkspaceIndex
        Kind                 = $Kind
        ContainerIndex       = $ContainerIndex
        ContainerWindowCount = $ContainerWindowCount
    }
}

function Get-WindowLocationMap {
    param(
        [Parameter(Mandatory)]
        [object]$State
    )

    $map = @{}
    $monitors = @(Get-RingElements -Ring $State.monitors)

    for ($monitorIndex = 0; $monitorIndex -lt $monitors.Count; $monitorIndex++) {
        $monitor = $monitors[$monitorIndex]
        $workspaces = @(Get-RingElements -Ring $monitor.workspaces)

        for ($workspaceIndex = 0; $workspaceIndex -lt $workspaces.Count; $workspaceIndex++) {
            $workspace = $workspaces[$workspaceIndex]
            $containers = @(Get-RingElements -Ring $workspace.containers)

            for ($containerIndex = 0; $containerIndex -lt $containers.Count; $containerIndex++) {
                $container = $containers[$containerIndex]
                $windows = @(Get-RingElements -Ring $container.windows)

                foreach ($window in $windows) {
                    Add-WindowLocation `
                        -Map $map `
                        -Window $window `
                        -MonitorIndex $monitorIndex `
                        -WorkspaceIndex $workspaceIndex `
                        -Kind "Tiling" `
                        -ContainerIndex $containerIndex `
                        -ContainerWindowCount $windows.Count
                }
            }

            $floatingProperty = $workspace.PSObject.Properties["floating_windows"]
            if ($null -ne $floatingProperty -and $null -ne $floatingProperty.Value) {
                foreach ($window in @(Get-RingElements -Ring $floatingProperty.Value)) {
                    Add-WindowLocation `
                        -Map $map `
                        -Window $window `
                        -MonitorIndex $monitorIndex `
                        -WorkspaceIndex $workspaceIndex `
                        -Kind "Floating"
                }
            }

            $monocleProperty = $workspace.PSObject.Properties["monocle_container"]
            if ($null -ne $monocleProperty -and $null -ne $monocleProperty.Value) {
                $monocleWindows = @(Get-RingElements -Ring $monocleProperty.Value.windows)
                foreach ($window in $monocleWindows) {
                    Add-WindowLocation `
                        -Map $map `
                        -Window $window `
                        -MonitorIndex $monitorIndex `
                        -WorkspaceIndex $workspaceIndex `
                        -Kind "Monocle" `
                        -ContainerWindowCount $monocleWindows.Count
                }
            }

            $maximizedProperty = $workspace.PSObject.Properties["maximized_window"]
            if ($null -ne $maximizedProperty -and $null -ne $maximizedProperty.Value) {
                Add-WindowLocation `
                    -Map $map `
                    -Window $maximizedProperty.Value `
                    -MonitorIndex $monitorIndex `
                    -WorkspaceIndex $workspaceIndex `
                    -Kind "Maximized"
            }
        }
    }

    return $map
}

function Get-NotificationEventType {
    param(
        [Parameter(Mandatory)]
        [object]$Notification
    )

    $eventProperty = $Notification.PSObject.Properties["event"]
    if ($null -eq $eventProperty -or $null -eq $eventProperty.Value) {
        return $null
    }

    $typeProperty = $eventProperty.Value.PSObject.Properties["type"]
    if ($null -eq $typeProperty -or $null -eq $typeProperty.Value) {
        return $null
    }

    return [string]$typeProperty.Value
}

function Get-NotificationEventWindow {
    param(
        [Parameter(Mandatory)]
        [object]$Notification
    )

    $eventProperty = $Notification.PSObject.Properties["event"]
    if ($null -eq $eventProperty -or $null -eq $eventProperty.Value) {
        return $null
    }

    $contentProperty = $eventProperty.Value.PSObject.Properties["content"]
    if ($null -eq $contentProperty -or $null -eq $contentProperty.Value) {
        return $null
    }

    $items = @($contentProperty.Value)
    for ($index = $items.Count - 1; $index -ge 0; $index--) {
        $item = $items[$index]
        if ($null -eq $item) {
            continue
        }

        $hwndProperty = $item.PSObject.Properties["hwnd"]
        if ($null -ne $hwndProperty -and $null -ne $hwndProperty.Value) {
            return $item
        }
    }

    return $null
}

function Get-NotificationEventHwnd {
    param(
        [Parameter(Mandatory)]
        [object]$Notification
    )

    $window = Get-NotificationEventWindow -Notification $Notification
    if ($null -eq $window) {
        return $null
    }

    return [Int64]$window.hwnd
}

function Get-WindowDiagnosticData {
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Window
    )

    $data = [ordered]@{}
    if ($null -eq $Window) {
        return $data
    }

    foreach ($propertyName in @("hwnd", "title", "exe", "class")) {
        $property = $Window.PSObject.Properties[$propertyName]
        if ($null -ne $property -and $null -ne $property.Value) {
            $data["window_$propertyName"] = $property.Value
        }
    }

    $rectProperty = $Window.PSObject.Properties["rect"]
    if ($null -ne $rectProperty -and $null -ne $rectProperty.Value) {
        $data["window_rect"] = [ordered]@{
            left   = $rectProperty.Value.left
            top    = $rectProperty.Value.top
            right  = $rectProperty.Value.right
            bottom = $rectProperty.Value.bottom
        }
    }

    return $data
}

function Get-WindowLocationDiagnosticData {
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Location
    )

    if ($null -eq $Location) {
        return $null
    }

    return [ordered]@{
        hwnd                   = $Location.Hwnd
        monitor_index          = $Location.MonitorIndex
        workspace_index        = $Location.WorkspaceIndex
        kind                   = $Location.Kind
        container_index        = $Location.ContainerIndex
        container_window_count = $Location.ContainerWindowCount
    }
}

function Get-KomorebiMonitorRectangle {
    param(
        [Parameter(Mandatory)]
        [object]$Monitor
    )

    $rect = $null
    $rectKind = $null

    foreach ($propertyName in @("size", "screen_rect", "work_area_size")) {
        $property = $Monitor.PSObject.Properties[$propertyName]
        if ($null -ne $property -and $null -ne $property.Value) {
            $rect = $property.Value
            $rectKind = $propertyName
            break
        }
    }

    if ($null -eq $rect) {
        return $null
    }

    $left = [Int64]$rect.left
    $top = [Int64]$rect.top

    $widthProperty = $rect.PSObject.Properties["width"]
    $heightProperty = $rect.PSObject.Properties["height"]

    if ($null -ne $widthProperty -and $null -ne $heightProperty) {
        $width = [Int64]$widthProperty.Value
        $height = [Int64]$heightProperty.Value
    }
    elseif ($rectKind -eq "size" -or $rectKind -eq "work_area_size") {
        # komorebi's Rect stores width in right and height in bottom.
        $width = [Int64]$rect.right
        $height = [Int64]$rect.bottom
    }
    else {
        # Older state versions used screen_rect; its right/bottom values were also dimensions.
        $width = [Int64]$rect.right
        $height = [Int64]$rect.bottom
    }

    if ($width -le 0 -or $height -le 0) {
        return $null
    }

    return [pscustomobject]@{
        Left   = $left
        Top    = $top
        Width  = $width
        Height = $height
    }
}

function Get-MonitorIndexAtPoint {
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [int]$X,

        [Parameter(Mandatory)]
        [int]$Y,

        [Parameter()]
        [string]$OperationId = ""
    )

    $monitors = @(Get-RingElements -Ring $State.monitors)
    if ($monitors.Count -eq 0) {
        Write-Diagnostic `
            -Level "Error" `
            -Event "cursor.monitor_match.no_monitors" `
            -Data ([ordered]@{
                operation_id = $OperationId
                cursor_x     = $X
                cursor_y     = $Y
            })
        throw "komorebi reported no monitors"
    }

    $nearestIndex = 0
    $nearestDistanceSquared = [double]::PositiveInfinity
    $monitorDiagnostics = @()

    for ($index = 0; $index -lt $monitors.Count; $index++) {
        $rectangle = Get-KomorebiMonitorRectangle -Monitor $monitors[$index]

        if ($null -eq $rectangle) {
            $monitorDiagnostics += [ordered]@{
                index           = $index
                valid_rectangle = $false
            }
            continue
        }

        $rightExclusive = $rectangle.Left + $rectangle.Width
        $bottomExclusive = $rectangle.Top + $rectangle.Height
        $containsPoint = (
            $X -ge $rectangle.Left -and
            $X -lt $rightExclusive -and
            $Y -ge $rectangle.Top -and
            $Y -lt $bottomExclusive
        )

        $dx = 0L
        if ($X -lt $rectangle.Left) {
            $dx = $rectangle.Left - $X
        }
        elseif ($X -ge $rightExclusive) {
            $dx = $X - ($rightExclusive - 1)
        }

        $dy = 0L
        if ($Y -lt $rectangle.Top) {
            $dy = $rectangle.Top - $Y
        }
        elseif ($Y -ge $bottomExclusive) {
            $dy = $Y - ($bottomExclusive - 1)
        }

        $distanceSquared = ([double]$dx * [double]$dx) + ([double]$dy * [double]$dy)

        $monitorDiagnostics += [ordered]@{
            index            = $index
            left             = $rectangle.Left
            top              = $rectangle.Top
            width            = $rectangle.Width
            height           = $rectangle.Height
            contains_cursor  = $containsPoint
            distance_squared = $distanceSquared
        }

        if ($containsPoint) {
            Write-Diagnostic `
                -Level "Debug" `
                -Event "cursor.monitor_match" `
                -Message "Cursor is inside a komorebi monitor rectangle." `
                -Data ([ordered]@{
                    operation_id          = $OperationId
                    cursor_x              = $X
                    cursor_y              = $Y
                    selected_monitor      = $index
                    used_nearest_fallback = $false
                    monitors              = $monitorDiagnostics
                })

            return $index
        }

        if ($distanceSquared -lt $nearestDistanceSquared) {
            $nearestDistanceSquared = $distanceSquared
            $nearestIndex = $index
        }
    }

    Write-Diagnostic `
        -Level "Warn" `
        -Event "cursor.monitor_match.fallback" `
        -Message "Cursor was outside every reported monitor rectangle; selected the nearest monitor." `
        -Data ([ordered]@{
            operation_id             = $OperationId
            cursor_x                 = $X
            cursor_y                 = $Y
            selected_monitor         = $nearestIndex
            nearest_distance_squared = $nearestDistanceSquared
            used_nearest_fallback    = $true
            monitors                 = $monitorDiagnostics
        })

    return $nearestIndex
}

function Invoke-KomorebicCommand {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter()]
        [string]$OperationId = ""
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $output = @()
    $exitCode = -1

    try {
        $output = @(& $script:KomorebicPath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    catch {
        $stopwatch.Stop()

        Write-ExceptionDiagnostic `
            -Event "komorebic.command.exception" `
            -ErrorRecord $_ `
            -Data ([ordered]@{
                operation_id = $OperationId
                arguments    = $Arguments
                elapsed_ms   = $stopwatch.ElapsedMilliseconds
            })

        throw
    }

    $stopwatch.Stop()

    $outputText = ($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    $isStateCommand = ($Arguments.Count -gt 0 -and $Arguments[0] -eq "state")
    $level = "Debug"

    if ($isStateCommand) {
        $level = "Trace"
    }

    if ($exitCode -ne 0) {
        $level = "Error"
    }

    $commandData = [ordered]@{
        operation_id = $OperationId
        arguments     = $Arguments
        exit_code     = $exitCode
        elapsed_ms    = $stopwatch.ElapsedMilliseconds
        output_length = $outputText.Length
    }

    if (-not $isStateCommand -or $exitCode -ne 0) {
        $commandData["output"] = Limit-DiagnosticText `
            -Text $outputText `
            -MaximumLength 8192
    }

    Write-Diagnostic `
        -Level $level `
        -Event "komorebic.command" `
        -Message "komorebic command completed." `
        -Data $commandData

    return [pscustomobject]@{
        ExitCode  = $exitCode
        Output    = $outputText
        ElapsedMs = $stopwatch.ElapsedMilliseconds
    }
}

function Get-KomorebiState {
    param(
        [Parameter()]
        [string]$OperationId = ""
    )

    $script:StateQueryCount = $script:StateQueryCount + 1
    $queryNumber = $script:StateQueryCount

    $result = Invoke-KomorebicCommand `
        -Arguments @("state") `
        -OperationId $OperationId

    if ($result.ExitCode -ne 0) {
        Write-Diagnostic `
            -Level "Error" `
            -Event "state.query.failed" `
            -Data ([ordered]@{
                operation_id       = $OperationId
                state_query_number = $queryNumber
                exit_code          = $result.ExitCode
                output             = (Limit-DiagnosticText -Text $result.Output -MaximumLength 8192)
            })

        throw "komorebic state failed with exit code $($result.ExitCode): $($result.Output)"
    }

    if ([string]::IsNullOrWhiteSpace($result.Output)) {
        Write-Diagnostic `
            -Level "Error" `
            -Event "state.query.empty" `
            -Data ([ordered]@{
                operation_id       = $OperationId
                state_query_number = $queryNumber
            })

        throw "komorebic state returned no JSON"
    }

    try {
        $state = $result.Output | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-ExceptionDiagnostic `
            -Event "state.query.invalid_json" `
            -ErrorRecord $_ `
            -Data ([ordered]@{
                operation_id       = $OperationId
                state_query_number = $queryNumber
                output             = (Limit-DiagnosticText -Text $result.Output -MaximumLength 8192)
            })

        throw
    }

    $monitorElements = @(Get-RingElements -Ring $state.monitors)
    $locationCount = (Get-WindowLocationMap -State $state).Count
    $focusedMonitorIndex = $null
    $focusedProperty = $state.monitors.PSObject.Properties["focused"]

    if ($null -ne $focusedProperty -and $null -ne $focusedProperty.Value) {
        $focusedMonitorIndex = [int]$focusedProperty.Value
    }

    Write-Diagnostic `
        -Level "Trace" `
        -Event "state.query.success" `
        -Data ([ordered]@{
            operation_id          = $OperationId
            state_query_number    = $queryNumber
            elapsed_ms            = $result.ElapsedMs
            monitor_count         = $monitorElements.Count
            focused_monitor_index = $focusedMonitorIndex
            managed_window_count  = $locationCount
        })

    return $state
}

function Test-KomorebiWindowFocused {
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [Int64]$Hwnd
    )

    $monitor = Get-FocusedRingElement -Ring $State.monitors
    if ($null -eq $monitor) {
        return $false
    }

    $workspace = Get-FocusedRingElement -Ring $monitor.workspaces
    if ($null -eq $workspace) {
        return $false
    }

    $maximizedProperty = $workspace.PSObject.Properties["maximized_window"]

    if ($null -ne $maximizedProperty -and $null -ne $maximizedProperty.Value) {
        $maximizedHwndProperty = $maximizedProperty.Value.PSObject.Properties["hwnd"]

        if (
            $null -ne $maximizedHwndProperty -and
            [Int64]$maximizedHwndProperty.Value -eq $Hwnd
        ) {
            return $true
        }
    }

    $monocleProperty = $workspace.PSObject.Properties["monocle_container"]

    if ($null -ne $monocleProperty -and $null -ne $monocleProperty.Value) {
        $monocleWindow = Get-FocusedRingElement -Ring $monocleProperty.Value.windows

        if ($null -ne $monocleWindow) {
            $monocleHwndProperty = $monocleWindow.PSObject.Properties["hwnd"]

            if (
                $null -ne $monocleHwndProperty -and
                [Int64]$monocleHwndProperty.Value -eq $Hwnd
            ) {
                return $true
            }
        }
    }

    $floatingProperty = $workspace.PSObject.Properties["floating_windows"]

    if ($null -ne $floatingProperty -and $null -ne $floatingProperty.Value) {
        $floatingWindow = Get-FocusedRingElement -Ring $floatingProperty.Value

        if ($null -ne $floatingWindow) {
            $floatingHwndProperty = $floatingWindow.PSObject.Properties["hwnd"]

            if (
                $null -ne $floatingHwndProperty -and
                [Int64]$floatingHwndProperty.Value -eq $Hwnd
            ) {
                return $true
            }
        }
    }

    $container = Get-FocusedRingElement -Ring $workspace.containers
    if ($null -eq $container) {
        return $false
    }

    $window = Get-FocusedRingElement -Ring $container.windows
    if ($null -eq $window) {
        return $false
    }

    $hwndProperty = $window.PSObject.Properties["hwnd"]

    return (
        $null -ne $hwndProperty -and
        [Int64]$hwndProperty.Value -eq $Hwnd
    )
}

function Request-ForegroundWindow {
    param(
        [Parameter(Mandatory)]
        [Int64]$Hwnd,

        [Parameter()]
        [string]$OperationId = ""
    )

    $target = [IntPtr]$Hwnd

    $initialForegroundHwnd = `
        [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::GetForegroundWindow().ToInt64()

    $isWindow = `
        [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::IsWindow($target)

    if (-not $isWindow) {
        Write-Diagnostic `
            -Level "Warn" `
            -Event "focus.request.invalid_window" `
            -Data ([ordered]@{
                operation_id   = $OperationId
                hwnd           = $Hwnd
                foreground_hwnd = $initialForegroundHwnd
            })

        return $false
    }

    if ($initialForegroundHwnd -eq $Hwnd) {
        Write-Diagnostic `
            -Level "Trace" `
            -Event "focus.request.already_foreground" `
            -Data ([ordered]@{
                operation_id = $OperationId
                hwnd         = $Hwnd
            })

        return $true
    }

    $wasIconic = `
        [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::IsIconic($target)

    $showWindowResult = $null

    if ($wasIconic) {
        # SW_RESTORE
        $showWindowResult = `
            [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::ShowWindowAsync(
                $target,
                9
            )
    }

    $currentThread = `
        [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::GetCurrentThreadId()

    $foregroundWindow = `
        [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::GetForegroundWindow()

    $foregroundThread = 0

    if ($foregroundWindow -ne [IntPtr]::Zero) {
        $foregroundThread = `
            [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::GetWindowThreadProcessId(
                $foregroundWindow,
                [IntPtr]::Zero
            )
    }

    $targetThread = `
        [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::GetWindowThreadProcessId(
            $target,
            [IntPtr]::Zero
        )

    $attachedForeground = $false
    $attachedTarget = $false
    $bringWindowToTopResult = $false
    $setForegroundWindowResult = $false

    try {
        if (
            $foregroundThread -ne 0 -and
            $foregroundThread -ne $currentThread
        ) {
            $attachedForeground = `
                [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::AttachThreadInput(
                    $currentThread,
                    $foregroundThread,
                    $true
                )
        }

        if (
            $targetThread -ne 0 -and
            $targetThread -ne $currentThread -and
            $targetThread -ne $foregroundThread
        ) {
            $attachedTarget = `
                [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::AttachThreadInput(
                    $currentThread,
                    $targetThread,
                    $true
                )
        }

        $bringWindowToTopResult = `
            [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::BringWindowToTop(
                $target
            )

        $setForegroundWindowResult = `
            [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::SetForegroundWindow(
                $target
            )
    }
    finally {
        if ($attachedTarget) {
            [void][KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::AttachThreadInput(
                $currentThread,
                $targetThread,
                $false
            )
        }

        if ($attachedForeground) {
            [void][KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::AttachThreadInput(
                $currentThread,
                $foregroundThread,
                $false
            )
        }
    }

    $finalForegroundHwnd = `
        [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::GetForegroundWindow().ToInt64()

    $success = ($finalForegroundHwnd -eq $Hwnd)
    $resultLevel = "Trace"

    if (-not $success) {
        $resultLevel = "Debug"
    }

    Write-Diagnostic `
        -Level $resultLevel `
        -Event "focus.request.result" `
        -Data ([ordered]@{
            operation_id                 = $OperationId
            hwnd                         = $Hwnd
            initial_foreground_hwnd      = $initialForegroundHwnd
            final_foreground_hwnd        = $finalForegroundHwnd
            was_iconic                   = $wasIconic
            show_window_result           = $showWindowResult
            current_thread_id            = $currentThread
            foreground_thread_id         = $foregroundThread
            target_thread_id             = $targetThread
            attached_foreground_thread   = $attachedForeground
            attached_target_thread       = $attachedTarget
            bring_window_to_top_result   = $bringWindowToTopResult
            set_foreground_window_result = $setForegroundWindowResult
            success                      = $success
        })

    return $success
}

function Wait-ForKomorebiWindowFocus {
    param(
        [Parameter(Mandatory)]
        [Int64]$Hwnd,

        [Parameter(Mandatory)]
        [int]$TimeoutMilliseconds,

        [Parameter()]
        [string]$OperationId = ""
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    $nextFocusRequest = [DateTime]::MinValue
    $pollCount = 0
    $focusRequestCount = 0
    $lastForegroundHwnd = 0L
    $lastKomorebiFocused = $false

    Write-Diagnostic `
        -Level "Debug" `
        -Event "focus.wait.begin" `
        -Data ([ordered]@{
            operation_id = $OperationId
            hwnd         = $Hwnd
            timeout_ms   = $TimeoutMilliseconds
        })

    do {
        $pollCount++
        $now = [DateTime]::UtcNow
        $focusRequestResult = $null

        if ($now -ge $nextFocusRequest) {
            $focusRequestCount++

            $focusRequestResult = Request-ForegroundWindow `
                -Hwnd $Hwnd `
                -OperationId $OperationId

            $nextFocusRequest = $now.AddMilliseconds(250)
        }

        $state = Get-KomorebiState -OperationId $OperationId

        $lastForegroundHwnd = `
            [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::GetForegroundWindow().ToInt64()

        $osFocused = ($lastForegroundHwnd -eq $Hwnd)
        $lastKomorebiFocused = Test-KomorebiWindowFocused `
            -State $state `
            -Hwnd $Hwnd

        $locationData = $null
        $locations = Get-WindowLocationMap -State $state
        $locationKey = [string]$Hwnd

        if ($locations.ContainsKey($locationKey)) {
            $locationData = Get-WindowLocationDiagnosticData `
                -Location $locations[$locationKey]
        }

        Write-Diagnostic `
            -Level "Trace" `
            -Event "focus.wait.poll" `
            -Data ([ordered]@{
                operation_id         = $OperationId
                hwnd                 = $Hwnd
                poll_count           = $pollCount
                focus_request_count  = $focusRequestCount
                focus_request_result = $focusRequestResult
                foreground_hwnd      = $lastForegroundHwnd
                os_focused           = $osFocused
                komorebi_focused     = $lastKomorebiFocused
                location             = $locationData
                elapsed_ms           = $stopwatch.ElapsedMilliseconds
            })

        if ($osFocused -and $lastKomorebiFocused) {
            $stopwatch.Stop()

            Write-Diagnostic `
                -Level "Debug" `
                -Event "focus.wait.success" `
                -Data ([ordered]@{
                    operation_id        = $OperationId
                    hwnd                = $Hwnd
                    poll_count          = $pollCount
                    focus_request_count = $focusRequestCount
                    elapsed_ms          = $stopwatch.ElapsedMilliseconds
                })

            return $state
        }

        Start-Sleep -Milliseconds 35
    }
    while ([DateTime]::UtcNow -lt $deadline)

    $stopwatch.Stop()

    Write-Diagnostic `
        -Level "Warn" `
        -Event "focus.wait.timeout" `
        -Message "Timed out waiting for Windows and komorebi to focus the target HWND." `
        -Data ([ordered]@{
            operation_id           = $OperationId
            hwnd                   = $Hwnd
            timeout_ms             = $TimeoutMilliseconds
            elapsed_ms             = $stopwatch.ElapsedMilliseconds
            poll_count             = $pollCount
            focus_request_count    = $focusRequestCount
            final_foreground_hwnd  = $lastForegroundHwnd
            final_komorebi_focused = $lastKomorebiFocused
        })

    return $null
}

function Restore-PreviousForegroundWindow {
    param(
        [Parameter(Mandatory)]
        [Int64]$PreviousForegroundHwnd,

        [Parameter(Mandatory)]
        [Int64]$MovedHwnd,

        [Parameter()]
        [string]$OperationId = ""
    )

    if ($PreviousForegroundHwnd -eq 0) {
        Write-Diagnostic `
            -Level "Trace" `
            -Event "focus.restore.skipped" `
            -Data ([ordered]@{
                operation_id = $OperationId
                reason       = "previous_foreground_is_zero"
                moved_hwnd   = $MovedHwnd
            })

        return
    }

    if ($PreviousForegroundHwnd -eq $MovedHwnd) {
        Write-Diagnostic `
            -Level "Trace" `
            -Event "focus.restore.skipped" `
            -Data ([ordered]@{
                operation_id = $OperationId
                reason       = "new_window_was_already_foreground"
                moved_hwnd   = $MovedHwnd
            })

        return
    }

    $previous = [IntPtr]$PreviousForegroundHwnd

    if (-not [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::IsWindow($previous)) {
        Write-Diagnostic `
            -Level "Debug" `
            -Event "focus.restore.skipped" `
            -Data ([ordered]@{
                operation_id             = $OperationId
                reason                   = "previous_foreground_no_longer_exists"
                previous_foreground_hwnd = $PreviousForegroundHwnd
                moved_hwnd               = $MovedHwnd
            })

        return
    }

    $restored = Request-ForegroundWindow `
        -Hwnd $PreviousForegroundHwnd `
        -OperationId $OperationId

    Write-Diagnostic `
        -Level "Debug" `
        -Event "focus.restore.result" `
        -Data ([ordered]@{
            operation_id             = $OperationId
            previous_foreground_hwnd = $PreviousForegroundHwnd
            moved_hwnd               = $MovedHwnd
            success                  = $restored
            final_foreground_hwnd    = [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::GetForegroundWindow().ToInt64()
        })
}

function Move-KomorebiWindowToMonitor {
    param(
        [Parameter(Mandatory)]
        [Int64]$Hwnd,

        [Parameter(Mandatory)]
        [int]$TargetMonitorIndex,

        [Parameter(Mandatory)]
        [object]$NotificationState,

        [Parameter(Mandatory)]
        [Int64]$PreviousForegroundHwnd,

        [Parameter()]
        [string]$OperationId = ""
    )

    if ([string]::IsNullOrWhiteSpace($OperationId)) {
        $OperationId = "hwnd-$Hwnd-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
    }

    $operationSucceeded = $false
    $outcome = "started"
    $originMonitorIndex = $null
    $restoreKomorebiMaximize = $false
    $restoreOriginMonocle = $false
    $moved = $false

    Write-Diagnostic `
        -Level "Info" `
        -Event "move.begin" `
        -Data ([ordered]@{
            operation_id             = $OperationId
            hwnd                     = $Hwnd
            target_monitor_index     = $TargetMonitorIndex
            previous_foreground_hwnd = $PreviousForegroundHwnd
        })

    try {
        $notificationLocations = Get-WindowLocationMap -State $NotificationState
        $locationKey = [string]$Hwnd

        if (-not $notificationLocations.ContainsKey($locationKey)) {
            $outcome = "missing-from-notification-state"

            Write-Diagnostic `
                -Level "Warn" `
                -Event "move.rejected.missing_from_notification_state" `
                -Data ([ordered]@{
                    operation_id         = $OperationId
                    hwnd                 = $Hwnd
                    target_monitor_index = $TargetMonitorIndex
                })

            return $false
        }

        $notificationLocation = $notificationLocations[$locationKey]
        $originMonitorIndex = [int]$notificationLocation.MonitorIndex

        Write-Diagnostic `
            -Level "Debug" `
            -Event "move.notification_location" `
            -Data ([ordered]@{
                operation_id         = $OperationId
                hwnd                 = $Hwnd
                target_monitor_index = $TargetMonitorIndex
                location             = (Get-WindowLocationDiagnosticData -Location $notificationLocation)
            })

        if ($notificationLocation.MonitorIndex -eq $TargetMonitorIndex) {
            $operationSucceeded = $true
            $outcome = "already-on-target"

            Write-Diagnostic `
                -Level "Info" `
                -Event "move.noop.already_on_target" `
                -Data ([ordered]@{
                    operation_id = $OperationId
                    hwnd         = $Hwnd
                    monitor_index = $TargetMonitorIndex
                })

            return $true
        }

        $state = Wait-ForKomorebiWindowFocus `
            -Hwnd $Hwnd `
            -TimeoutMilliseconds $FocusTimeoutMilliseconds `
            -OperationId $OperationId

        if ($null -eq $state) {
            $outcome = "initial-focus-timeout"

            Write-Diagnostic `
                -Level "Warn" `
                -Event "move.failed.focus_timeout" `
                -Message "Could not focus the new window before moving it." `
                -Data ([ordered]@{
                    operation_id         = $OperationId
                    hwnd                 = $Hwnd
                    target_monitor_index = $TargetMonitorIndex
                })

            return $false
        }

        $locations = Get-WindowLocationMap -State $state

        if (-not $locations.ContainsKey($locationKey)) {
            $outcome = "window-disappeared"

            Write-Diagnostic `
                -Level "Warn" `
                -Event "move.failed.window_disappeared" `
                -Data ([ordered]@{
                    operation_id = $OperationId
                    hwnd         = $Hwnd
                })

            return $false
        }

        $location = $locations[$locationKey]

        Write-Diagnostic `
            -Level "Debug" `
            -Event "move.location_after_focus" `
            -Data ([ordered]@{
                operation_id = $OperationId
                hwnd         = $Hwnd
                location     = (Get-WindowLocationDiagnosticData -Location $location)
            })

        if ($location.MonitorIndex -eq $TargetMonitorIndex) {
            $operationSucceeded = $true
            $outcome = "arrived-before-command"

            Write-Diagnostic `
                -Level "Info" `
                -Event "move.noop.arrived_before_command" `
                -Data ([ordered]@{
                    operation_id = $OperationId
                    hwnd         = $Hwnd
                    monitor_index = $TargetMonitorIndex
                })

            return $true
        }

        if ($location.Kind -eq "Maximized") {
            Write-Diagnostic `
                -Level "Debug" `
                -Event "move.prepare.unmaximize" `
                -Data ([ordered]@{
                    operation_id = $OperationId
                    hwnd         = $Hwnd
                })

            $toggleMaximize = Invoke-KomorebicCommand `
                -Arguments @("toggle-maximize") `
                -OperationId $OperationId

            if ($toggleMaximize.ExitCode -ne 0) {
                $outcome = "unmaximize-failed"

                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "move.failed.unmaximize" `
                    -Data ([ordered]@{
                        operation_id = $OperationId
                        hwnd         = $Hwnd
                        output       = (Limit-DiagnosticText -Text $toggleMaximize.Output -MaximumLength 8192)
                    })

                return $false
            }

            $restoreKomorebiMaximize = $true

            $state = Wait-ForKomorebiWindowFocus `
                -Hwnd $Hwnd `
                -TimeoutMilliseconds $FocusTimeoutMilliseconds `
                -OperationId $OperationId
        }
        elseif ($location.Kind -eq "Monocle") {
            Write-Diagnostic `
                -Level "Debug" `
                -Event "move.prepare.leave_monocle" `
                -Data ([ordered]@{
                    operation_id = $OperationId
                    hwnd         = $Hwnd
                })

            $toggleMonocle = Invoke-KomorebicCommand `
                -Arguments @("toggle-monocle") `
                -OperationId $OperationId

            if ($toggleMonocle.ExitCode -ne 0) {
                $outcome = "leave-monocle-failed"

                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "move.failed.leave_monocle" `
                    -Data ([ordered]@{
                        operation_id = $OperationId
                        hwnd         = $Hwnd
                        output       = (Limit-DiagnosticText -Text $toggleMonocle.Output -MaximumLength 8192)
                    })

                return $false
            }

            $restoreOriginMonocle = $true

            $state = Wait-ForKomorebiWindowFocus `
                -Hwnd $Hwnd `
                -TimeoutMilliseconds $FocusTimeoutMilliseconds `
                -OperationId $OperationId
        }

        if ($null -eq $state) {
            $outcome = "focus-lost-during-prepare"

            Write-Diagnostic `
                -Level "Warn" `
                -Event "move.failed.focus_lost_during_prepare" `
                -Data ([ordered]@{
                    operation_id = $OperationId
                    hwnd         = $Hwnd
                })

            return $false
        }

        $locations = Get-WindowLocationMap -State $state

        if (-not $locations.ContainsKey($locationKey)) {
            $outcome = "missing-after-prepare"

            Write-Diagnostic `
                -Level "Warn" `
                -Event "move.failed.missing_after_prepare" `
                -Data ([ordered]@{
                    operation_id = $OperationId
                    hwnd         = $Hwnd
                })

            return $false
        }

        $location = $locations[$locationKey]

        # move-to-monitor moves the focused container. Isolate a newly appended
        # stacked window first so existing windows do not move with it.
        if (
            $location.Kind -eq "Tiling" -and
            $location.ContainerWindowCount -gt 1
        ) {
            Write-Diagnostic `
                -Level "Info" `
                -Event "move.prepare.unstack" `
                -Data ([ordered]@{
                    operation_id          = $OperationId
                    hwnd                  = $Hwnd
                    container_window_count = $location.ContainerWindowCount
                    container_index       = $location.ContainerIndex
                })

            $unstack = Invoke-KomorebicCommand `
                -Arguments @("unstack") `
                -OperationId $OperationId

            if ($unstack.ExitCode -ne 0) {
                $outcome = "unstack-failed"

                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "move.failed.unstack" `
                    -Message "Refusing to move the entire stack after unstack failed." `
                    -Data ([ordered]@{
                        operation_id = $OperationId
                        hwnd         = $Hwnd
                        output       = (Limit-DiagnosticText -Text $unstack.Output -MaximumLength 8192)
                    })

                return $false
            }

            $state = Wait-ForKomorebiWindowFocus `
                -Hwnd $Hwnd `
                -TimeoutMilliseconds $FocusTimeoutMilliseconds `
                -OperationId $OperationId

            if ($null -eq $state) {
                $outcome = "focus-lost-after-unstack"

                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "move.failed.focus_lost_after_unstack" `
                    -Data ([ordered]@{
                        operation_id = $OperationId
                        hwnd         = $Hwnd
                    })

                return $false
            }
        }

        for ($attempt = 1; $attempt -le 2; $attempt++) {
            Write-Diagnostic `
                -Level "Info" `
                -Event "move.attempt.begin" `
                -Data ([ordered]@{
                    operation_id         = $OperationId
                    hwnd                 = $Hwnd
                    attempt              = $attempt
                    target_monitor_index = $TargetMonitorIndex
                })

            $state = Wait-ForKomorebiWindowFocus `
                -Hwnd $Hwnd `
                -TimeoutMilliseconds $FocusTimeoutMilliseconds `
                -OperationId $OperationId

            if ($null -eq $state) {
                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "move.attempt.focus_timeout" `
                    -Data ([ordered]@{
                        operation_id = $OperationId
                        hwnd         = $Hwnd
                        attempt      = $attempt
                    })

                continue
            }

            $locations = Get-WindowLocationMap -State $state

            if ($locations.ContainsKey($locationKey)) {
                $location = $locations[$locationKey]

                Write-Diagnostic `
                    -Level "Debug" `
                    -Event "move.attempt.pre_command_location" `
                    -Data ([ordered]@{
                        operation_id = $OperationId
                        hwnd         = $Hwnd
                        attempt      = $attempt
                        location     = (Get-WindowLocationDiagnosticData -Location $location)
                    })

                if ($location.MonitorIndex -eq $TargetMonitorIndex) {
                    $moved = $true
                    break
                }
            }

            $moveResult = Invoke-KomorebicCommand `
                -Arguments @(
                    "move-to-monitor",
                    [string]$TargetMonitorIndex
                ) `
                -OperationId $OperationId

            if ($moveResult.ExitCode -ne 0) {
                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "move.attempt.command_failed" `
                    -Data ([ordered]@{
                        operation_id         = $OperationId
                        hwnd                 = $Hwnd
                        attempt              = $attempt
                        target_monitor_index = $TargetMonitorIndex
                        exit_code            = $moveResult.ExitCode
                        output               = (Limit-DiagnosticText -Text $moveResult.Output -MaximumLength 8192)
                    })

                Start-Sleep -Milliseconds 80
                continue
            }

            $verifyStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            $verifyDeadline = [DateTime]::UtcNow.AddMilliseconds(
                $MoveVerificationTimeoutMilliseconds
            )

            $verificationPoll = 0

            do {
                $verificationPoll++

                $verifyState = Get-KomorebiState `
                    -OperationId $OperationId

                $verifyLocations = Get-WindowLocationMap `
                    -State $verifyState

                $verifyLocationData = $null

                if ($verifyLocations.ContainsKey($locationKey)) {
                    $verifyLocation = $verifyLocations[$locationKey]

                    $verifyLocationData = Get-WindowLocationDiagnosticData `
                        -Location $verifyLocation

                    if ($verifyLocation.MonitorIndex -eq $TargetMonitorIndex) {
                        $moved = $true
                    }
                }

                Write-Diagnostic `
                    -Level "Trace" `
                    -Event "move.verify.poll" `
                    -Data ([ordered]@{
                        operation_id         = $OperationId
                        hwnd                 = $Hwnd
                        attempt              = $attempt
                        verification_poll    = $verificationPoll
                        target_monitor_index = $TargetMonitorIndex
                        location             = $verifyLocationData
                        moved                = $moved
                        elapsed_ms           = $verifyStopwatch.ElapsedMilliseconds
                    })

                if ($moved) {
                    break
                }

                Start-Sleep -Milliseconds 40
            }
            while ([DateTime]::UtcNow -lt $verifyDeadline)

            $verifyStopwatch.Stop()

            Write-Diagnostic `
                -Level "Debug" `
                -Event "move.verify.result" `
                -Data ([ordered]@{
                    operation_id         = $OperationId
                    hwnd                 = $Hwnd
                    attempt              = $attempt
                    target_monitor_index = $TargetMonitorIndex
                    moved                = $moved
                    verification_polls   = $verificationPoll
                    elapsed_ms           = $verifyStopwatch.ElapsedMilliseconds
                })

            if ($moved) {
                break
            }
        }

        if (-not $moved) {
            $outcome = "verification-failed"

            Write-Diagnostic `
                -Level "Warn" `
                -Event "move.failed.verification" `
                -Message "komorebi did not report the target HWND on the requested monitor." `
                -Data ([ordered]@{
                    operation_id         = $OperationId
                    hwnd                 = $Hwnd
                    origin_monitor_index = $originMonitorIndex
                    target_monitor_index = $TargetMonitorIndex
                })

            return $false
        }

        if ($restoreKomorebiMaximize) {
            $restoreMaximize = Invoke-KomorebicCommand `
                -Arguments @("toggle-maximize") `
                -OperationId $OperationId

            if ($restoreMaximize.ExitCode -ne 0) {
                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "move.postprocess.restore_maximize_failed" `
                    -Data ([ordered]@{
                        operation_id = $OperationId
                        hwnd         = $Hwnd
                        output       = (Limit-DiagnosticText -Text $restoreMaximize.Output -MaximumLength 8192)
                    })
            }
        }

        if ($restoreOriginMonocle) {
            $focusOrigin = Invoke-KomorebicCommand `
                -Arguments @(
                    "focus-monitor",
                    [string]$originMonitorIndex
                ) `
                -OperationId $OperationId

            if ($focusOrigin.ExitCode -eq 0) {
                $restoreMonocle = Invoke-KomorebicCommand `
                    -Arguments @("toggle-monocle") `
                    -OperationId $OperationId

                if ($restoreMonocle.ExitCode -ne 0) {
                    Write-Diagnostic `
                        -Level "Warn" `
                        -Event "move.postprocess.restore_monocle_failed" `
                        -Data ([ordered]@{
                            operation_id         = $OperationId
                            origin_monitor_index = $originMonitorIndex
                            output               = (Limit-DiagnosticText -Text $restoreMonocle.Output -MaximumLength 8192)
                        })
                }
            }
            else {
                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "move.postprocess.focus_origin_failed" `
                    -Data ([ordered]@{
                        operation_id         = $OperationId
                        origin_monitor_index = $originMonitorIndex
                        output               = (Limit-DiagnosticText -Text $focusOrigin.Output -MaximumLength 8192)
                    })
            }

            [void](Invoke-KomorebicCommand `
                -Arguments @(
                    "focus-monitor",
                    [string]$TargetMonitorIndex
                ) `
                -OperationId $OperationId)
        }

        $operationSucceeded = $true
        $outcome = "moved"

        Write-Diagnostic `
            -Level "Info" `
            -Event "move.success" `
            -Data ([ordered]@{
                operation_id         = $OperationId
                hwnd                 = $Hwnd
                origin_monitor_index = $originMonitorIndex
                target_monitor_index = $TargetMonitorIndex
            })

        return $true
    }
    catch {
        $outcome = "exception"

        Write-ExceptionDiagnostic `
            -Event "move.exception" `
            -ErrorRecord $_ `
            -Data ([ordered]@{
                operation_id         = $OperationId
                hwnd                 = $Hwnd
                origin_monitor_index = $originMonitorIndex
                target_monitor_index = $TargetMonitorIndex
            })

        return $false
    }
    finally {
        try {
            Restore-PreviousForegroundWindow `
                -PreviousForegroundHwnd $PreviousForegroundHwnd `
                -MovedHwnd $Hwnd `
                -OperationId $OperationId
        }
        catch {
            Write-ExceptionDiagnostic `
                -Event "focus.restore.exception" `
                -ErrorRecord $_ `
                -Level "Warn" `
                -Data ([ordered]@{
                    operation_id             = $OperationId
                    previous_foreground_hwnd = $PreviousForegroundHwnd
                    moved_hwnd               = $Hwnd
                })
        }

        Write-Diagnostic `
            -Level "Debug" `
            -Event "move.end" `
            -Data ([ordered]@{
                operation_id         = $OperationId
                hwnd                 = $Hwnd
                origin_monitor_index = $originMonitorIndex
                target_monitor_index = $TargetMonitorIndex
                success              = $operationSucceeded
                outcome              = $outcome
            })
    }
}

$command = $null
$script:KomorebicPath = $null
$mutex = $null
$ownsMutex = $false
$pipe = $null
$pump = $null
$subscribed = $false
$pipeName = "komorebi_mouse_spawner_$PID"
$fatalError = $false
$originalMouseFollowsFocus = $null
$mouseFollowsFocusChanged = $false

try {
    $powerShellEdition = $null

    if ($PSVersionTable.PSObject.Properties["PSEdition"]) {
        $powerShellEdition = $PSVersionTable.PSEdition
    }

    Write-Diagnostic `
        -Level "Info" `
        -Event "process.start" `
        -Message "Starting komorebi mouse-monitor subscriber." `
        -Data ([ordered]@{
            script_path                  = $PSCommandPath
            powershell_version           = $PSVersionTable.PSVersion.ToString()
            powershell_edition           = $powerShellEdition
            os_version                   = [Environment]::OSVersion.VersionString
            is_64bit_process             = [Environment]::Is64BitProcess
            configured_komorebic         = $Komorebic
            focus_timeout_ms             = $FocusTimeoutMilliseconds
            move_verification_timeout_ms = $MoveVerificationTimeoutMilliseconds
            log_level                    = $LogLevel
            log_raw_notifications        = [bool]$LogRawNotifications
            keep_mouse_follows_focus     = [bool]$KeepMouseFollowsFocus
            pipe_name                    = $pipeName
        })

    $command = Get-Command `
        -Name $Komorebic `
        -CommandType Application `
        -ErrorAction Stop

    $script:KomorebicPath = $command.Source

    if ([string]::IsNullOrWhiteSpace($script:KomorebicPath)) {
        $script:KomorebicPath = $command.Path
    }

    Write-Diagnostic `
        -Level "Info" `
        -Event "komorebic.resolved" `
        -Data ([ordered]@{
            path = $script:KomorebicPath
        })

    $versionResult = Invoke-KomorebicCommand `
        -Arguments @("--version")

    if ($versionResult.ExitCode -eq 0) {
        Write-Diagnostic `
            -Level "Info" `
            -Event "komorebic.version" `
            -Data ([ordered]@{
                version_output = $versionResult.Output.Trim()
            })
    }
    else {
        Write-Diagnostic `
            -Level "Warn" `
            -Event "komorebic.version_failed" `
            -Data ([ordered]@{
                exit_code = $versionResult.ExitCode
                output    = (Limit-DiagnosticText -Text $versionResult.Output -MaximumLength 4096)
            })
    }

    $createdNew = $false

    $mutex = [System.Threading.Mutex]::new(
        $true,
        "Local\komorebi_mouse_spawner",
        [ref]$createdNew
    )

    if (-not $createdNew) {
        Write-Diagnostic `
            -Level "Error" `
            -Event "process.duplicate_instance" `
            -Message "Another subscriber instance owns the mutex."

        throw "Another instance of this subscriber is already running."
    }

    $ownsMutex = $true

    Write-Diagnostic `
        -Level "Debug" `
        -Event "mutex.acquired"

    # komorebi can move the cursor to a newly focused window before the Show/Manage
    # notification reaches this subscriber. In that case the event-time cursor
    # position describes the window's spawn monitor rather than the monitor the
    # user selected before launching the application. Disable mouse-follows-focus
    # while this subscriber is active, then restore the original value on exit.
    $startupState = Get-KomorebiState `
        -OperationId "startup.mouse_follows_focus"

    $mouseFollowsFocusProperty = `
        $startupState.PSObject.Properties["mouse_follows_focus"]

    if (
        $null -eq $mouseFollowsFocusProperty -or
        $null -eq $mouseFollowsFocusProperty.Value
    ) {
        Write-Diagnostic `
            -Level "Warn" `
            -Event "mouse_follows_focus.state_unavailable" `
            -Message "The komorebi state did not expose mouse_follows_focus."
    }
    else {
        $originalMouseFollowsFocus = [bool]$mouseFollowsFocusProperty.Value

        Write-Diagnostic `
            -Level "Info" `
            -Event "mouse_follows_focus.detected" `
            -Data ([ordered]@{
                original_value = $originalMouseFollowsFocus
                keep_requested = [bool]$KeepMouseFollowsFocus
            })

        if (
            $originalMouseFollowsFocus -and
            -not $KeepMouseFollowsFocus
        ) {
            $disableMouseFollowsFocus = Invoke-KomorebicCommand `
                -Arguments @(
                    "mouse-follows-focus",
                    "disable"
                ) `
                -OperationId "startup.mouse_follows_focus"

            if ($disableMouseFollowsFocus.ExitCode -ne 0) {
                throw "Could not disable komorebi mouse-follows-focus: $($disableMouseFollowsFocus.Output)"
            }

            # Mark this immediately so cleanup restores the setting even if the
            # verification query below fails.
            $mouseFollowsFocusChanged = $true

            $mouseFollowsFocusVerificationState = Get-KomorebiState `
                -OperationId "startup.mouse_follows_focus.verify"

            $verificationProperty = `
                $mouseFollowsFocusVerificationState.PSObject.Properties["mouse_follows_focus"]

            $verifiedDisabled = (
                $null -ne $verificationProperty -and
                $null -ne $verificationProperty.Value -and
                -not [bool]$verificationProperty.Value
            )

            Write-Diagnostic `
                -Level $(if ($verifiedDisabled) { "Info" } else { "Error" }) `
                -Event "mouse_follows_focus.disabled" `
                -Data ([ordered]@{
                    original_value    = $originalMouseFollowsFocus
                    verified_disabled = $verifiedDisabled
                })

            if (-not $verifiedDisabled) {
                throw "komorebi accepted the mouse-follows-focus disable command, but state still reports it enabled."
            }
        }
        elseif (
            $originalMouseFollowsFocus -and
            $KeepMouseFollowsFocus
        ) {
            Write-Diagnostic `
                -Level "Warn" `
                -Event "mouse_follows_focus.left_enabled" `
                -Message "Mouse-follows-focus remains enabled by request; event-time cursor coordinates may point at the spawn monitor."
        }
        else {
            Write-Diagnostic `
                -Level "Info" `
                -Event "mouse_follows_focus.already_disabled"
        }
    }

    $pipe = [System.IO.Pipes.NamedPipeServerStream]::new(
        $pipeName,
        [System.IO.Pipes.PipeDirection]::In,
        1,
        [System.IO.Pipes.PipeTransmissionMode]::Byte,
        [System.IO.Pipes.PipeOptions]::Asynchronous,
        65536,
        65536
    )

    Write-Diagnostic `
        -Level "Info" `
        -Event "pipe.created" `
        -Data ([ordered]@{
            pipe_name          = $pipeName
            input_buffer_size  = 65536
            output_buffer_size = 65536
        })

    # Start reading before subscribe-pipe. The initial notification contains the
    # entire state and can exceed a small pipe buffer.
    $pump = [KomorebiMouseSpawnerDiagnosticsV1.PipeMessagePump]::new($pipe)
    $pump.Start()

    Write-Diagnostic `
        -Level "Debug" `
        -Event "pipe.reader_started"

    $subscribe = Invoke-KomorebicCommand `
        -Arguments @(
            "subscribe-pipe",
            $pipeName
        )

    if ($subscribe.ExitCode -ne 0) {
        throw "komorebic subscribe-pipe failed: $($subscribe.Output)"
    }

    $subscribed = $true

    Write-Diagnostic `
        -Level "Info" `
        -Event "pipe.subscription_registered" `
        -Data ([ordered]@{
            pipe_name = $pipeName
        })

    if (-not $pump.Connected.Wait(5000)) {
        Write-Diagnostic `
            -Level "Error" `
            -Event "pipe.connection_timeout" `
            -Data ([ordered]@{
                pipe_name = $pipeName
                timeout_ms = 5000
            })

        throw "komorebi did not connect to the named pipe within 5 seconds."
    }

    if ($null -ne $pump.Error) {
        throw $pump.Error
    }

    Write-Diagnostic `
        -Level "Info" `
        -Event "pipe.connected" `
        -Data ([ordered]@{
            pipe_name = $pipeName
        })

    [KomorebiMouseSpawnerDiagnosticsV1.PipeMessage]$baselineMessage = $null

    if (-not $pump.Messages.TryTake([ref]$baselineMessage, 5000)) {
        if ($null -ne $pump.Error) {
            throw $pump.Error
        }

        throw "No initial notification was received from komorebi."
    }

    try {
        $baselineNotification = `
            $baselineMessage.Line | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-ExceptionDiagnostic `
            -Event "baseline.invalid_json" `
            -ErrorRecord $_ `
            -Data ([ordered]@{
                pipe_sequence = $baselineMessage.Sequence
                raw           = (Limit-DiagnosticText -Text $baselineMessage.Line -MaximumLength 16384)
            })

        throw
    }

    if ($LogRawNotifications) {
        Write-Diagnostic `
            -Level "Debug" `
            -Event "pipe.notification.raw" `
            -Data ([ordered]@{
                pipe_sequence    = $baselineMessage.Sequence
                raw_notification = $baselineMessage.Line
            })
    }

    $seenHwnds = [System.Collections.Generic.HashSet[System.Int64]]::new()

    $baselineLocations = Get-WindowLocationMap `
        -State $baselineNotification.state

    foreach ($key in $baselineLocations.Keys) {
        [void]$seenHwnds.Add([Int64]$key)
    }

    $monitorTopology = @()

    $baselineMonitors = @(
        Get-RingElements -Ring $baselineNotification.state.monitors
    )

    for (
        $monitorIndex = 0;
        $monitorIndex -lt $baselineMonitors.Count;
        $monitorIndex++
    ) {
        $monitor = $baselineMonitors[$monitorIndex]
        $rectangle = Get-KomorebiMonitorRectangle -Monitor $monitor

        $workspaceCount = @(
            Get-RingElements -Ring $monitor.workspaces
        ).Count

        $monitorName = $null
        $monitorDevice = $null

        if ($monitor.PSObject.Properties["name"]) {
            $monitorName = $monitor.name
        }

        if ($monitor.PSObject.Properties["device"]) {
            $monitorDevice = $monitor.device
        }

        $monitorTopology += [ordered]@{
            index           = $monitorIndex
            name            = $monitorName
            device          = $monitorDevice
            rectangle       = $rectangle
            workspace_count = $workspaceCount
        }
    }

    Write-Diagnostic `
        -Level "Info" `
        -Event "baseline.loaded" `
        -Data ([ordered]@{
            pipe_sequence                 = $baselineMessage.Sequence
            captured_utc                  = $baselineMessage.CapturedUtc.ToString("o")
            baseline_event_type           = (Get-NotificationEventType -Notification $baselineNotification)
            existing_window_count         = $seenHwnds.Count
            monitor_count                 = $baselineMonitors.Count
            monitor_topology              = $monitorTopology
            monitor_usr_idx_map           = $baselineNotification.state.monitor_usr_idx_map
            mouse_follows_focus           = $baselineNotification.state.mouse_follows_focus
            original_mouse_follows_focus  = $originalMouseFollowsFocus
            mouse_follows_focus_changed   = $mouseFollowsFocusChanged
            focus_follows_mouse           = $baselineNotification.state.focus_follows_mouse
        })

    while ($true) {
        [KomorebiMouseSpawnerDiagnosticsV1.PipeMessage]$message = $null

        if (-not $pump.Messages.TryTake([ref]$message, 1000)) {
            if ($null -ne $pump.Error) {
                throw $pump.Error
            }

            if ($pump.Messages.IsCompleted) {
                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "pipe.reader_completed" `
                    -Message "The pipe reader completed; stopping the event loop."

                break
            }

            Write-Diagnostic `
                -Level "Trace" `
                -Event "event_loop.idle" `
                -Data ([ordered]@{
                    queue_depth = $pump.Messages.Count
                })

            continue
        }

        $processingStartedUtc = [DateTime]::UtcNow

        $queueLagMs = [Math]::Round(
            ($processingStartedUtc - $message.CapturedUtc).TotalMilliseconds,
            3
        )

        try {
            $notification = `
                $message.Line | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-ExceptionDiagnostic `
                -Event "pipe.notification.invalid_json" `
                -ErrorRecord $_ `
                -Data ([ordered]@{
                    pipe_sequence = $message.Sequence
                    captured_utc  = $message.CapturedUtc.ToString("o")
                    queue_lag_ms  = $queueLagMs
                    raw           = (Limit-DiagnosticText -Text $message.Line -MaximumLength 16384)
                })

            continue
        }

        try {
            $eventType = Get-NotificationEventType `
                -Notification $notification

            $eventWindow = Get-NotificationEventWindow `
                -Notification $notification

            $eventHwnd = $null

            if ($null -ne $eventWindow) {
                $eventHwnd = [Int64]$eventWindow.hwnd
            }

            $stateFocusedMonitorIndex = $null

            $stateFocusedMonitorProperty = `
                $notification.state.monitors.PSObject.Properties["focused"]

            if (
                $null -ne $stateFocusedMonitorProperty -and
                $null -ne $stateFocusedMonitorProperty.Value
            ) {
                $stateFocusedMonitorIndex = `
                    [int]$stateFocusedMonitorProperty.Value
            }

            $stateMouseFollowsFocus = $null

            $stateMouseFollowsFocusProperty = `
                $notification.state.PSObject.Properties["mouse_follows_focus"]

            if ($null -ne $stateMouseFollowsFocusProperty) {
                $stateMouseFollowsFocus = `
                    $stateMouseFollowsFocusProperty.Value
            }

            $stateFocusFollowsMouse = $null

            $stateFocusFollowsMouseProperty = `
                $notification.state.PSObject.Properties["focus_follows_mouse"]

            if ($null -ne $stateFocusFollowsMouseProperty) {
                $stateFocusFollowsMouse = `
                    $stateFocusFollowsMouseProperty.Value
            }

            $notificationData = [ordered]@{
                pipe_sequence                 = $message.Sequence
                captured_utc                  = $message.CapturedUtc.ToString("o")
                queue_lag_ms                  = $queueLagMs
                queue_depth_after_take        = $pump.Messages.Count
                event_type                    = $eventType
                event_hwnd                    = $eventHwnd
                cursor_x                      = $message.CursorX
                cursor_y                      = $message.CursorY
                cursor_position_available     = $message.CursorPositionAvailable
                used_physical_cursor_position = $message.UsedPhysicalCursorPosition
                captured_foreground_hwnd      = $message.ForegroundHwnd
                processing_foreground_hwnd    = [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::GetForegroundWindow().ToInt64()
                state_focused_monitor_index   = $stateFocusedMonitorIndex
                state_mouse_follows_focus     = $stateMouseFollowsFocus
                state_focus_follows_mouse     = $stateFocusFollowsMouse
                notification_length           = $message.Line.Length
            }

            $windowData = Get-WindowDiagnosticData `
                -Window $eventWindow

            foreach ($key in $windowData.Keys) {
                $notificationData[$key] = $windowData[$key]
            }

            $notificationLogLevel = "Trace"

            if ($null -ne $eventHwnd) {
                $notificationLogLevel = "Debug"
            }

            Write-Diagnostic `
                -Level $notificationLogLevel `
                -Event "pipe.notification" `
                -Data $notificationData

            if ($LogRawNotifications) {
                Write-Diagnostic `
                    -Level "Debug" `
                    -Event "pipe.notification.raw" `
                    -Data ([ordered]@{
                        pipe_sequence    = $message.Sequence
                        event_type       = $eventType
                        raw_notification = $message.Line
                    })
            }

            if (
                $null -ne $eventHwnd -and
                $queueLagMs -ge 500
            ) {
                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "pipe.notification.queue_lag" `
                    -Message "A window event waited in the in-memory queue before processing." `
                    -Data ([ordered]@{
                        pipe_sequence          = $message.Sequence
                        event_type             = $eventType
                        event_hwnd             = $eventHwnd
                        queue_lag_ms           = $queueLagMs
                        queue_depth_after_take = $pump.Messages.Count
                    })
            }

            if (
                (
                    $eventType -eq "Destroy" -or
                    $eventType -eq "Unmanage"
                ) -and
                $null -ne $eventHwnd
            ) {
                $wasTracked = $seenHwnds.Remove([Int64]$eventHwnd)

                Write-Diagnostic `
                    -Level "Debug" `
                    -Event "window.tracking.removed" `
                    -Data ([ordered]@{
                        pipe_sequence       = $message.Sequence
                        event_type          = $eventType
                        hwnd                = $eventHwnd
                        was_tracked         = $wasTracked
                        tracked_window_count = $seenHwnds.Count
                    })

                continue
            }

            if ($eventType -notin @("Show", "Uncloak", "Manage")) {
                if ($null -ne $eventHwnd) {
                    Write-Diagnostic `
                        -Level "Debug" `
                        -Event "window.event.ignored" `
                        -Data ([ordered]@{
                            pipe_sequence = $message.Sequence
                            event_type    = $eventType
                            hwnd          = $eventHwnd
                            reason        = "event_type_is_not_window_addition_candidate"
                        })
                }

                continue
            }

            if ($null -eq $eventHwnd) {
                Write-Diagnostic `
                    -Level "Debug" `
                    -Event "window.event.ignored" `
                    -Data ([ordered]@{
                        pipe_sequence = $message.Sequence
                        event_type    = $eventType
                        reason        = "event_has_no_hwnd"
                    })

                continue
            }

            $eventHwnd = [Int64]$eventHwnd

            if ($seenHwnds.Contains($eventHwnd)) {
                Write-Diagnostic `
                    -Level "Debug" `
                    -Event "window.event.ignored" `
                    -Data ([ordered]@{
                        pipe_sequence = $message.Sequence
                        event_type    = $eventType
                        hwnd          = $eventHwnd
                        reason        = "hwnd_already_tracked"
                    })

                continue
            }

            $locations = Get-WindowLocationMap `
                -State $notification.state

            $locationKey = [string]$eventHwnd

            if (-not $locations.ContainsKey($locationKey)) {
                Write-Diagnostic `
                    -Level "Debug" `
                    -Event "window.event.ignored" `
                    -Message "The event state did not contain this HWND as a managed window." `
                    -Data ([ordered]@{
                        pipe_sequence = $message.Sequence
                        event_type    = $eventType
                        hwnd          = $eventHwnd
                        reason        = "hwnd_not_present_in_notification_state"
                    })

                continue
            }

            $operationId = "pipe-$($message.Sequence)-hwnd-$eventHwnd"
            $originLocation = $locations[$locationKey]

            if (-not $message.CursorPositionAvailable) {
                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "cursor.capture.failed" `
                    -Message "Both GetPhysicalCursorPos and GetCursorPos failed; captured coordinates may be invalid." `
                    -Data ([ordered]@{
                        operation_id  = $operationId
                        pipe_sequence = $message.Sequence
                        hwnd          = $eventHwnd
                        cursor_x      = $message.CursorX
                        cursor_y      = $message.CursorY
                    })
            }
            elseif (-not $message.UsedPhysicalCursorPosition) {
                Write-Diagnostic `
                    -Level "Debug" `
                    -Event "cursor.capture.fallback" `
                    -Message "GetPhysicalCursorPos failed; GetCursorPos supplied the coordinates." `
                    -Data ([ordered]@{
                        operation_id  = $operationId
                        pipe_sequence = $message.Sequence
                        hwnd          = $eventHwnd
                        cursor_x      = $message.CursorX
                        cursor_y      = $message.CursorY
                    })
            }

            # Mark before moving so notifications generated by our own commands cannot
            # create a duplicate operation when the queued messages are processed later.
            [void]$seenHwnds.Add($eventHwnd)

            $targetMonitorIndex = Get-MonitorIndexAtPoint `
                -State $notification.state `
                -X $message.CursorX `
                -Y $message.CursorY `
                -OperationId $operationId

            $candidateData = [ordered]@{
                operation_id                 = $operationId
                pipe_sequence                = $message.Sequence
                event_type                   = $eventType
                hwnd                         = $eventHwnd
                cursor_x                     = $message.CursorX
                cursor_y                     = $message.CursorY
                cursor_position_available    = $message.CursorPositionAvailable
                captured_foreground_hwnd     = $message.ForegroundHwnd
                processing_foreground_hwnd   = [KomorebiMouseSpawnerDiagnosticsV1.NativeMethods]::GetForegroundWindow().ToInt64()
                queue_lag_ms                 = $queueLagMs
                state_focused_monitor_index  = $stateFocusedMonitorIndex
                state_mouse_follows_focus    = $stateMouseFollowsFocus
                state_focus_follows_mouse    = $stateFocusFollowsMouse
                origin_location              = (Get-WindowLocationDiagnosticData -Location $originLocation)
                target_monitor_index         = $targetMonitorIndex
                tracked_window_count         = $seenHwnds.Count
            }

            foreach ($key in $windowData.Keys) {
                $candidateData[$key] = $windowData[$key]
            }

            Write-Diagnostic `
                -Level "Info" `
                -Event "window.candidate" `
                -Message "Detected a previously unseen managed HWND." `
                -Data $candidateData

            $moveSucceeded = Move-KomorebiWindowToMonitor `
                -Hwnd $eventHwnd `
                -TargetMonitorIndex $targetMonitorIndex `
                -NotificationState $notification.state `
                -PreviousForegroundHwnd $message.ForegroundHwnd `
                -OperationId $operationId

            $resultLevel = "Info"

            if (-not $moveSucceeded) {
                $resultLevel = "Warn"
            }

            Write-Diagnostic `
                -Level $resultLevel `
                -Event "window.candidate.result" `
                -Data ([ordered]@{
                    operation_id         = $operationId
                    pipe_sequence        = $message.Sequence
                    hwnd                 = $eventHwnd
                    target_monitor_index = $targetMonitorIndex
                    success              = $moveSucceeded
                    note                 = "The HWND remains tracked after a failed attempt, matching the original script behavior."
                })
        }
        catch {
            Write-ExceptionDiagnostic `
                -Event "pipe.notification.processing_exception" `
                -ErrorRecord $_ `
                -Data ([ordered]@{
                    pipe_sequence = $message.Sequence
                    captured_utc  = $message.CapturedUtc.ToString("o")
                    queue_lag_ms  = $queueLagMs
                })

            continue
        }
    }
}
catch {
    $fatalError = $true

    Write-ExceptionDiagnostic `
        -Event "process.fatal" `
        -ErrorRecord $_

    throw
}
finally {
    Write-Diagnostic `
        -Level "Info" `
        -Event "process.cleanup.begin" `
        -Data ([ordered]@{
            subscribed                  = $subscribed
            pipe_name                   = $pipeName
            fatal_error                 = $fatalError
            original_mouse_follows_focus = $originalMouseFollowsFocus
            mouse_follows_focus_changed  = $mouseFollowsFocusChanged
        })

    if ($subscribed) {
        try {
            $unsubscribeResult = Invoke-KomorebicCommand `
                -Arguments @(
                    "unsubscribe-pipe",
                    $pipeName
                )

            if ($unsubscribeResult.ExitCode -ne 0) {
                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "pipe.unsubscribe_failed" `
                    -Data ([ordered]@{
                        pipe_name = $pipeName
                        exit_code = $unsubscribeResult.ExitCode
                        output    = (Limit-DiagnosticText -Text $unsubscribeResult.Output -MaximumLength 8192)
                    })
            }
            else {
                Write-Diagnostic `
                    -Level "Info" `
                    -Event "pipe.unsubscribed" `
                    -Data ([ordered]@{
                        pipe_name = $pipeName
                    })
            }
        }
        catch {
            Write-ExceptionDiagnostic `
                -Event "pipe.unsubscribe_exception" `
                -ErrorRecord $_ `
                -Level "Warn" `
                -Data ([ordered]@{
                    pipe_name = $pipeName
                })
        }
    }

    if ($mouseFollowsFocusChanged) {
        try {
            $restoreMouseFollowsFocus = Invoke-KomorebicCommand `
                -Arguments @(
                    "mouse-follows-focus",
                    "enable"
                ) `
                -OperationId "cleanup.mouse_follows_focus"

            if ($restoreMouseFollowsFocus.ExitCode -ne 0) {
                Write-Diagnostic `
                    -Level "Warn" `
                    -Event "mouse_follows_focus.restore_failed" `
                    -Data ([ordered]@{
                        original_value = $originalMouseFollowsFocus
                        exit_code      = $restoreMouseFollowsFocus.ExitCode
                        output         = (Limit-DiagnosticText -Text $restoreMouseFollowsFocus.Output -MaximumLength 8192)
                    })
            }
            else {
                Write-Diagnostic `
                    -Level "Info" `
                    -Event "mouse_follows_focus.restored" `
                    -Data ([ordered]@{
                        restored_value = $true
                    })
            }
        }
        catch {
            Write-ExceptionDiagnostic `
                -Event "mouse_follows_focus.restore_exception" `
                -ErrorRecord $_ `
                -Level "Warn" `
                -Data ([ordered]@{
                    original_value = $originalMouseFollowsFocus
                })
        }
    }

    if ($null -ne $pump) {
        try {
            $pump.Dispose()

            Write-Diagnostic `
                -Level "Debug" `
                -Event "pipe.reader_disposed"
        }
        catch {
            Write-ExceptionDiagnostic `
                -Event "pipe.reader_dispose_exception" `
                -ErrorRecord $_ `
                -Level "Warn"
        }
    }
    elseif ($null -ne $pipe) {
        try {
            $pipe.Dispose()

            Write-Diagnostic `
                -Level "Debug" `
                -Event "pipe.disposed"
        }
        catch {
            Write-ExceptionDiagnostic `
                -Event "pipe.dispose_exception" `
                -ErrorRecord $_ `
                -Level "Warn"
        }
    }

    if ($ownsMutex -and $null -ne $mutex) {
        try {
            $mutex.ReleaseMutex()

            Write-Diagnostic `
                -Level "Debug" `
                -Event "mutex.released"
        }
        catch {
            Write-ExceptionDiagnostic `
                -Event "mutex.release_exception" `
                -ErrorRecord $_ `
                -Level "Warn"
        }
    }

    if ($null -ne $mutex) {
        try {
            $mutex.Dispose()
        }
        catch {
            Write-ExceptionDiagnostic `
                -Event "mutex.dispose_exception" `
                -ErrorRecord $_ `
                -Level "Warn"
        }
    }

    Write-Diagnostic `
        -Level "Info" `
        -Event "process.cleanup.end" `
        -Data ([ordered]@{
            fatal_error                  = $fatalError
            total_log_records            = $script:LogSequence
            total_state_queries          = $script:StateQueryCount
            original_mouse_follows_focus = $originalMouseFollowsFocus
            mouse_follows_focus_changed  = $mouseFollowsFocusChanged
        })
}
