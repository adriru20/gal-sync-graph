function Write-LogEvent {
    param (
        [validateset("Info", "Error", "Debug")][string]$Level = "Info",
        [parameter(Mandatory)][string]$Message
    )
    $timeStamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

    $logOutput = $timeStamp, $Level, $Message -join " | "

    Write-Output $logOutput
}