$LastWake = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Power-Troubleshooter'; Id=1} -MaxEvents 1 | Select-Object -ExpandProperty TimeCreated
New-TimeSpan -Start $LastWake -End (Get-Date)
