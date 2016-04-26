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
  [string]$InstanceName = $server.InstanceNAme
  $hash = @{
    "Username" = "$Username"; "Password" = "$Password" ; "SystemIdentifier" = "$SystemIdentifier" ;
    "Hostname" = "$Hostname" ; "InstanceName" = "$InstanceName"
  }
  return $hash
}

[System.Xml.XmlElement]$Metrics = $Config.Settings.MetricGroups

ForEach($metric in $Metrics.ChildNodes)
{
  [string]$ServiceName = $metric.ServiceName
  [string]$MetricGroupName = $metric.MetricGroupName
  [string]$MetricGroupLabel = $metric.MetricGroupLabel
  [string]$MonitoringFrequency = $metric.Frequency
  [string]$DashboardName = $metric.DashboardName
  [System.Xml.XmlElement]$Servers = $metric.Servers

  Create-MetricGroup $ApiServer $Apikey $ServiceName $MetricGroupName $MetricGroupLabel $MonitoringFrequency
  $arguments = $args -split " "
  Foreach ($arg in $arguments)
  {
    if($arg -eq '-MakeDashboard')
    {
      Create-Dashboard $ApiServer $Apikey $ServiceName $DashboardName
      Write-Log "Dashboard created"
      exit 0
    }
  }

  ForEach ($server in $Servers.ChildNodes)
  {
  $hash = ParseNodeToXML($server)
  $arguments = @($args, $hash, $Apikey, $ApiServer, $MetricGroupName, $MonitoringFrequency)
  $job = Start-Job -filepath "$PSScriptRoot\SQL-Worker.ps1" -ArgumentList $arguments
  Write-Log "Spawning worker thread : $($job|out-string)"
  }
}

$SleepTime = 0
while($TRUE)
{
$jobs = Get-job
$StopJob = Test-Path -Path "$env:temp\stop-ucm-monitor.txt"
if ($StopJob)
{
Write-Log "Stopping job as requested by user."
Remove-Item "$env:temp\stop-ucm-monitor.txt"
exit 0
}
if ($SleepTime % 60 -eq 0)
{
Write-Host "Running $($jobs.count) workers. Check ucm-metrics.log for any worker logs."
Write-Host "Press Ctrl+C to stop monitoring"
$SleepTime = 0
}
Start-Sleep -s 1
$SleepTime++
}
