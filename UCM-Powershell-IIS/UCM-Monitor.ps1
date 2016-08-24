
$root = $PSScriptRoot

. $root\Utils.ps1
. $root\Create-MetricGroups.ps1
. $root\Create-Dashboards.ps1

function ParseNodeToXML($server)
{
  [string]$Username = $server.Username
  [string]$Password = $server.Password
  [string]$SystemIdentifier = $server.systemidentifier
  [string]$Hostname = $server.Hostname
  [string]$InstanceName = $server.InstanceName
  $hash = @{
    "Username" = "$Username"; "Password" = "$Password" ; "SystemIdentifier" = "$SystemIdentifier" ;
    "Hostname" = "$Hostname" ; "InstanceName" = "$InstanceName"
  }
  return $hash
}

[System.Xml.XmlElement]$Metrics = $Config.Settings.MetricGroups

# Setting execution policy to unrestricted so that no user is required to reply to security prompts once script starts running
Set-ExecutionPolicy Unrestricted

Write-Log "Starting monitoring agent."


$counter = 0
ForEach($metric in $Metrics.ChildNodes)
{
  [string]$ServiceName = $metric.ServiceName
  [string]$MetricGroupName = $metric.MetricGroupName
  [string]$MetricGroupLabel = $metric.MetricGroupLabel
  [string]$MonitoringFrequency = $metric.Frequency
  [string]$DashboardName = $metric.DashboardName
  [System.Xml.XmlElement]$Servers = $metric.Servers

  Create-MetricGroup $ApiServer $Apikey $ServiceName $MetricGroupName $MetricGroupLabel $MonitoringFrequency
  ForEach ($server in $Servers.ChildNodes)
  {
    $hash = ParseNodeToXML($server)
    $arguments = @($args, $hash, $Apikey, $ApiServer, $MetricGroupName, $MonitoringFrequency, $PSScriptRoot)
    if($counter -eq 0) {
      $job = Start-Job -filepath "$root\Worker.ps1" -ArgumentList $arguments
      Write-Log "Spawning worker thread : $($job|out-string)"
      $counter  = 1
    }
  }
}

$SleepTime = 0
while($TRUE)
{
  $jobs = Get-job
  $StopJob = Test-Path -Path "$env:temp\stop-ucm-iis-monitor.txt"
  if ($StopJob) {
    Write-Log "Stopping job as requested by user."
    Remove-Item "$env:temp\stop-ucm-iis-monitor.txt"
    exit 0
  }
  if ($SleepTime % 60 -eq 0) {
    Write-log "Running $($jobs.count) workers. Check ucm-metrics.log for any worker logs."
    Write-log "Press Ctrl+C to stop monitoring"
    $SleepTime = 0
  }
  Start-Sleep -s 1
  $SleepTime++
}
