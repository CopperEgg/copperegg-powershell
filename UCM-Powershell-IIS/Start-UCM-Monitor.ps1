$root = $PSScriptRoot

. $root\Utils.ps1

if ($PSVersionTable.PSVersion.Major -lt 3)
{
  Write-Host "Minimum powershell version required is 3.0. Please update your powershell version"
  Write-Host "The script will exit in 5 seconds"
  Start-Sleep -s 5
  exit -1
}

# Remove the temp file so that script doesn't stop as soon as it starts
Try
{
  Remove-Item "$env:temp\stop-ucm-iis-monitor.txt" -EA Stop
}
Catch [system.exception]
{
  # Control comes here if that file doesn't exist. No problem if the file is not present; do nothing
}

Write-log "Launching main script. Please allow it to run with admin rights"
Start-Sleep -s 2

Start-Process Powershell -WindowStyle Hidden -Verb RunAs -ArgumentList "-file `"$root\UCM-Monitor.ps1`" `"$args`""
