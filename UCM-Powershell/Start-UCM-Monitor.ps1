<# Use this script to start the monitoring process. It does some basic checks and then calls
   the script which spawns workers based on no. of instances to be monitored.
#>

if ($PSVersionTable.PSVersion.Major -lt 3)
{
  Write-Host "Minimum powershell version required is 3.0. Please update your powershell version"
  Write-Host "The script will exit in 5 seconds"
  Start-Sleep -s 5
  exit -1
}
Write-Host "Launching main script. Please allow it to run with admin rights"
Start-Sleep -s 2
Start-Process Powershell -Verb RunAs -ArgumentList "-file `"C:\Program Files\UCM-Powershell\UCM-SQL-Monitor.ps1`" `"$args`""
