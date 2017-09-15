
$root = $PSScriptRoot

. $root\Utils.ps1
. $root\Create-MetricGroups.ps1
. $root\Create-Dashboards.ps1

function ParseServerNodeToXML($server)
{
  [string]$Username = $server.Username
  [string]$Password = $server.Password
  [string]$SystemIdentifier = $server.SystemIdentifier
  [string]$Hostname = $server.Hostname
  [string]$HostAddress = $server.HostAddress
  $hash = @{
    "Username" = "$Username"; "Password" = "$Password" ; "SystemIdentifier" = "$SystemIdentifier" ;
    "Hostname" = "$Hostname" ; "HostAddress" = "$HostAddress"
  }
  return $hash
}

function ParseSiteNodeToXML($site)
{
  [string]$SiteName = $site.SiteName
  [string]$IpAddress = $site.IpAddress
  [string]$Port = $site.Port
  $hash = @{
    "SiteName" = "$SiteName"; "IpAddress" = "$IpAddress" ; "Port" = "$Port"
  }
  return $hash
}

[System.Xml.XmlElement]$Metrics = $Config.Settings.MetricGroups

# Setting execution policy to unrestricted so that no user is required to reply to security prompts once script starts running
Set-ExecutionPolicy Unrestricted

Write-Log "Starting monitoring agent."

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
    [System.Xml.XmlElement]$Sites = $server.Sites
    ForEach ($site in $Sites.ChildNodes)
    {
      $ServerHash = ParseServerNodeToXML($server)
      $SiteHash = ParseSiteNodeToXML($site)
      $arguments = @($args, $ServerHash, $SiteHash, $Apikey, $ApiServer, $MetricGroupName, $MonitoringFrequency, $PSScriptRoot)
      $job = Start-Job -filepath "$root\Worker.ps1" -ArgumentList $arguments
      Write-Log "Spawning worker thread : $($job|out-string)"
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
