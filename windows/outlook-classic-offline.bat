:: https://mikecrowley.us/2018/07/05/start-outlook-in-offline-mode-without-opening-it-first/

reg add "HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Outlook\Profiles\Outlook\0a0d020000000000c000000000000046" /t REG_BINARY /v "00030398" /d "01000000" /f
