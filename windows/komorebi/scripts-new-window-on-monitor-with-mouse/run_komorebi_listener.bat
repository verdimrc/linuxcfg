@echo off

:: Force close any old background pipe subscriptions first
komorebic.exe unsubscribe-pipe komorebi_mouse_spawner 

:: Launches the PowerShell script silently without showing a terminal window
powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0komorebi_mouse_spawn.ps1"
:: powershell -NoExit             -ExecutionPolicy Bypass -File "%~dp0komorebi_mouse_spawn.ps1"
