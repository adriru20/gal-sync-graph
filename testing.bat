@echo off

PowerShell.exe -ExecutionPolicy Bypass ^
-File "%CD%\Sync-Contacts.ps1" ^
-CredentialPath "%CD%\Credentials\credential.cred" ^
-Tenant "4e5d6375-3b91-4537-af13-53b7c61de53e" ^
-ContactFolderName "TESTING" ^
-LogPath "%CD%\log" ^
-AzureADGroup "GAL_Testing"

pause