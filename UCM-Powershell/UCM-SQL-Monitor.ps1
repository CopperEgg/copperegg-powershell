<# Parent script which is called by Start-UCM-Monitor. 
   It reads common parameters from the config file and :

   1. Creates metric group on every start. If metric group already exists, it is not created.
   2. For each server defined in config.xml, it launches a dedicated worker.
   3. Keeps looping infinitely so that child workers can do required work.
   4. If '-MakeDashboard' option is passed, it also creates dashboard for Metric Group. 
   5. Other arguments (like -Debug) are passed to workers.

   If you change config.xml, you need to restart this service.
#>

$root = $PSScriptRoot

. $root\Utils.ps1 
. $root\Create-MetricGroups.ps1
. $root\Create-Dashboards.ps1

# Setting execution policy to unrestricted so that no user is required to reply to security prompts once script starts running
Set-ExecutionPolicy Unrestricted

Write-Log "Starting monitoring agent."

<# This variable is an array of all the SQL servers defined in config.xml.
   Each index holds more information about each server (instance name, hostname, credentials etc)
#>
[System.Xml.XmlElement]$SQLServers = $Config.Settings.SQLServers

[string]$MetricGroupName = $Config.Settings.SQLServersCommonSettings.MetricGroupName
[string]$MetricGroupLabel = $Config.Settings.SQLServersCommonSettings.MetricGroupLabel
[string]$MonitoringFrequency = $Config.Settings.SQLServersCommonSettings.Frequency
[string]$DashboardName = $Config.Settings.SQLServersCommonSettings.DashboardName

Create-MetricGroup $ApiServer $Apikey  $MetricGroupName $MetricGroupLabel $MonitoringFrequency
$arguments = $args -split " "
Foreach ($arg in $arguments)
{
  if($arg -eq '-MakeDashboard')
  {
    Create-Dashboard $ApiServer $Apikey $DashboardName
    Write-Log "Dashboard created"
  }
}

ForEach ($server in $SQLServers.ChildNodes)
{
  $arguments = @($args, $server, $Apikey, $ApiServer, $MetricGroupName, $MonitoringFrequency)
  $job = Start-Job -filepath "$PSScriptRoot\Monitor-Worker.ps1" -ArgumentList $arguments
  Write-Log "Spawning worker thread : $($job|out-string)"
}
while($TRUE)
{
  $jobs = Get-job
  Write-Host "Running $($jobs.count) workers. Check copperegg-metrics.log for any worker logs. 
              Press Ctrl+C to stop monitoring"
  Start-Sleep -s 60
}
