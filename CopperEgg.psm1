#
# CopperEgg.psm1 contains the core components of the CopperEgg powershell module.
# Copyright (c) 2012 CopperEgg Corporation. All rights reserved.
#
# The where_am_i functions provides a simple way to avoid path issues
function where_am_i {$myInvocation}

[string]$global:mypath = $null
[string]$global:computer = (gc env:computername).ToString()
[string]$global:apikey = $null
[string]$global:local_remote = 'local'
$global:frequency = 120
$global:cuconfig = @{}
[string[]]$global:all_metricgroupids = @()
$global:all_metricgroups = @{}
[string[]]$global:all_dashboardids = @()
[string[]]$global:dashes_tobuild = @()
[string[]]$global:all_serverids = @()
$global:master_hash = @{}

# set the global script location variable
$global:mypath = (where_am_i).PSScriptRoot.ToString()
$LogDir = "$global:mypath\Logs"
$Logfile = "CopperEgg_$global:computer.log"
$MaxLogFileSizeMB = 5 # After a log file reaches this size it will archive the existing and create a new one

function LogFileCheck
{
  # Check if log file directory exists - if not, create and then create the log file
  if (!(Test-Path $LogDir)) {
    mkdir $LogDir
    New-Item "$LogDir\$LogFile" -type file
    break
  }
  if(Test-Path "$LogDir\$LogFile"){
    # Check size of log file - archive existing file if over limit and create fresh.
    if (((gci "$LogDir\$LogFile").length/1MB) -gt $MaxLogFileSizeMB) {
      $NewLogFile = $LogFile.replace(".log", " ARCHIVED $(Get-Date -Format dd-MM-yyy-hh-mm-ss).log")
      ren "$LogDir\$LogFile" "$LogDir\$NewLogFile"
      New-Item "$LogDir\$LogFile" -type file
    }
  }
}

Function Write-CuEggLog
{
   Param ([string]$logstring)
   LogFileCheck
   $TimeStamp = Get-Date -Format dd-MM-yyy-hh-mm-ss
   $message = "$Timestamp  $logstring"
   Add-content $LogDir\$LogFile -value $message -PassThru
}
Export-ModuleMember -function Write-CuEggLog

trap
[Exception] {
LogWrite "error: $($_.Exception.GetType().Name) - $($_.Exception.Message)"
}



# Convert MS Counter path to CopperEgg metric name
function ConvertTo-CEName {
param(
    [string]$counter
  )
    $a = $counter
    $a = $a.replace( '*','_total')
    $a = $a.replace( '#','Number')
    $a = $a.replace( '%','Percent')
    $a = $a.replace( '$','_')
    $a = $a.replace(' / ','/')
    $a = $a.replace('/','_per_')
    $a = $a.replace('\','_')
    $a = $a.replace( ' ','_')
    $a = $a.replace( '.','')
    $a = $a.replace( ':','_')
    $a = $a.replace( '(','_')
    $a = $a.replace( ')','_')
    $a = $a.replace( '___','_')
    $a = $a.replace( '__','_')
  if($a.StartsWith("_") -eq $TRUE){
    $a = $a.Substring(1)
  }
    return [string]$a
}
export-modulemember -function ConvertTo-CEName

# Remove-CounterInstances eliminates instances, where possible
function Remove-CounterInstances {
param(
  [string]$counter
  )
    $a = $counter
    if ( $a.Contains("NET") )
    {  $a = $a.replace( '*','_global_') }
    else
    { $a = $a.replace( '*','_total') }
    return [string]$a
}
export-modulemember -function Remove-CounterInstances

# Send-CEGet formats and sends a CopperEgg API Get command
function Send-CEGet {
param(
    [string]$apikey,
    [string]$apicmd,
    $data
  )
  $uri = 'https://api.copperegg.com/v2' + $apicmd
  $authinfo = $apikey + ':U'
  $auth = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($authinfo))
  $req = New-Object System.Net.WebClient
  $req.Headers.Add('Authorization', $auth )
  $req.Headers.Add('Accept', 'application/json')
  $req.Headers.Add("user-agent", "PowerShell")
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
  [System.Net.ServicePointManager]::Expect100Continue = $false
  $req.Headers.Add('Content-Type', 'application/json')
  try 
  {
    $result = $req.DownloadString($uri)
  }
  catch [Exception] 
  {
    Write-CuEggLog "*** System Exception: Unable to send GET to CopperEgg. Please Check Internet Connectivity. ***"
    $result = $null
  }
  return $result
}
export-modulemember -function Send-CEGet

# Send-CEPost formats and sends a CopperEgg API Post command
# TODO: add exception processing, retries
function Send-CEPost {
param(
    [string]$apikey,
    [string]$apicmd,
    $data
  )
  $uri = "https://api.copperegg.com/v2$apicmd"
  $authinfo = $apikey + ':U'
  $auth = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($authinfo))
  $req = New-Object System.Net.WebClient
  $req.Headers.Add('Authorization', $auth )
  $req.Headers.Add('Accept', '*/*')
  $req.Headers.Add("user-agent", "PowerShell")
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
  [System.Net.ServicePointManager]::Expect100Continue = $false
  $req.Headers.Add('Content-Type', 'application/json')
  $data_json = $data | ConvertTo-JSON -Depth 5

  Try 
  {
    $result = $req.UploadString($uri, $data_json)
  }
  Catch [system.exception]
  {
    Write-CuEggLog "*** System Exception: Unable to send POST to CopperEgg. Please Check Internet Connectivity. ***"
    $result =  $null
  }
  return $result
}
export-modulemember -function Send-CEPost


# Send-CEPut formats and sends a CopperEgg API Put command
# TODO: add exception processing, retries
function Send-CEPut {
param(
    [string]$apikey,
    [string]$apicmd,
    $data
  )
  $uri = "https://api.copperegg.com/v2$apicmd"
  $webRequest = [System.Net.WebRequest]::Create($uri)
  $webRequest.ContentType = "application/json"
  $authinfo = $apikey + ':U'
  $auth = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($authinfo))
  $webRequest.Headers.Add('Authorization', $auth )
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
  [System.Net.ServicePointManager]::Expect100Continue = $false
  $data_json = $data | ConvertTo-JSON -Depth 5
  $data_json = [System.Text.Encoding]::UTF8.GetBytes($data_json)
  $webRequest.Method = "PUT"
  $requestStream = $webRequest.GetRequestStream()
  $requestStream.Write($data_json, 0,$data_json.length)
  $requestStream.Close()

  [System.Net.WebResponse] $resp = $webRequest.GetResponse();
  $rs = $resp.GetResponseStream();
  [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
  [string] $result = $sr.ReadToEnd();

  return $result
}
export-modulemember -function Send-CEPut


function New-MetricGroup {
param(
    [string]$group_name,
    $groupcfg
  )
  Write-CuEggLog "Checking for metric group $group_name"

  [string]$cmd =  "/revealmetrics/metric_groups/$group_name.json?show_hidden=1"
  $rslt = Send-CEGet $global:apikey $cmd ""
  Write-CuEggLog "The get result is $rslt"

  if($rslt -ne $null){
    $rslt_decode = $rslt | ConvertFrom-Json
    $mgarray = $rslt_decode | Where-Object {$_.name -eq $group_name}
    if($mgarray -ne $null){
      Write-CuEggLog "Metric group $group_name found; merge and update"
      # do merge and update
      $rslt = Send-CEPut $global:apikey "/revealmetrics/metric_groups/$group_name.json?show_hidden=1" $groupcfg
      Write-CuEggLog "The put result is $rslt"
      return $group_name
    }
   }
  # metric group doesn't exist ... create it
  Write-CuEggLog "Not Found. Creating metric group $group_name"
  $rslt = Send-CEPost $global:apikey '/revealmetrics/metric_groups.json' $groupcfg
  if($rslt -ne $null){
    $check_group_name = ($rslt | ConvertFrom-Json).name.ToString()
    Write-CuEggLog "Created metric group $check_group_name"
    return $check_group_name
  }
  else {
    Write-CuEggLog "Error Creating $group_name"
  }
  return $null
}
export-modulemember -function New-MetricGroup


# New-Dashboard will:
#   first check for the existence of the metric group
#   if it exists, it will not be changed
#   if it does not exist, it will be created
#
function New-Dashboard {
param(
    [string]$dash_name,
    $dashcfg
  )
  Write-CuEggLog "Checking for Dashboard $dash_name"
  [string]$cmd =  '/revealmetrics/dashboards.json'
  $rslt = Send-CEGet $global:apikey $cmd ""
  [int]$found = 0
  if( $rslt -ne $null ){
    $new = $rslt | ConvertFrom-Json
    foreach($name in $new.name) {
      if( $dash_name -eq $name.ToString() ) {
        $found = 1
        break
      }
    }
  }
  if( $found -eq 0 ){
    Write-CuEggLog "Not Found. Creating Dashboard $dash_name"
    $rslt = Send-CEPost $global:apikey $cmd $dashcfg
    if($rslt -ne $null){
      $new = ($rslt | ConvertFrom-Json).name.ToString()
      Write-CuEggLog "Created Dashboard $new"
    }
    else {
      Write-CuEggLog "Error Creating $dash_name"
    }
  }
  else {
    Write-CuEggLog "Found $dash_name"
  }
  return $rslt
}
export-modulemember -function New-Dashboard

# Send-CEMetrics is the routine used to send sample data to CopperEgg
# TODO: change to While( $True )
function Send-CEMetrics {
param(
  [string[]]$MSCounters,
  [string]$group_name
  )
  # Convert the result into an array of strings so it works with get-counter.
  [string[]]$result = $MSCounters.replace(",","`n")
  $metric_data = @{}
  [int]$epochtime = 0
  $unixEpochStart = new-object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
  $i = 1
  While($i -lt 100) {
    $metric_data = $null
    $metric_data = new-object @{}
    $samples = Get-Counter -Counter $result
    foreach($counter in $samples){
      $sample=$counter.CounterSamples[0]
      if($sample.Timestamp.Kind -eq 'Local'){
        [DateTime]$utc = $sample.Timestamp.ToUniversalTime()
      }else{
        [DateTime]$utc = $sample.Timestamp
      }
      $epochtime=($utc - $unixEpochStart).TotalSeconds
      foreach($sample in $counter.CounterSamples){
        [string]$path = $sample.Path.ToString()
        if ($path.StartsWith('\\') -eq 'True'){
          [int]$off = $path.IndexOfAny('\', 2)
          [string]$path = $path.Substring($off).ToString()
        }
        $metric_data.Add( $master_hash.Get_Item($path), $sample.CookedValue )
      }
    }
    $apicmd = '/revealmetrics/samples/' + $group_name + '.json'
    $payload = New-Object PSObject -Property @{
      "timestamp"=$epochtime;
      [string]"identifier"=$global:computer.ToString();
      "values"=$metric_data
    }
    $rslt = Send-CEPost $global:apikey $apicmd $payload
    Start-Sleep -s 10
    $i++
  }
}
Export-ModuleMember -function Send-CEMetrics

function Get-ServerCounter {
param(
  [string[]]$server,
  [string[]]$counter
  )
  if ($env:COMPUTERNAME -eq $server) {
      Get-Counter -Counter $counter
  } else {
      Get-Counter -computername $server -Counter $counter
  }
}
Export-ModuleMember -function Get-ServerCounter


function Find-MetricGroup {
 param(
  [string]$group_name
   )
  $global:all_metricgroups[$group_name]
}
Export-ModuleMember -function Find-MetricGroup


# Hostnames of systems where this metric group will be monitored
# input is the metric group id
function Find-IncludedHosts {
  param(
   [string]$mg_id
  )
  [string[]]$hosts = @()
  foreach( $id in $global:all_serverids ) {
    $hn = $global:cuconfig.$id.hostname
    $mgl = $global:cuconfig.$id.metricgroups
    foreach($mg in $mgl) {
      if($mg_id -eq $mg) {
        #Write-CuEggLog "Included-Hosts: Server id $id Hostname $hn includes monitoring of $mg_id"
        if($global:local_remote -eq 'local'){
          if($hn -eq $global:computer ){
            $hosts += $hn
          }
        } elseif($global:local_remote -eq 'remote'){
          if($hn -ne $global:computer){
            $hosts += $hn
          }
        } else {
          #all
          $hosts += $hn
        }
      }
    }
  }
  return [string[]]$hosts
}
Export-ModuleMember -function Find-IncludedHosts

# find mssql instance names of all mssql servers on this host
# input is the hostname of the server
function Find-InstanceNames {
 param(
  [string]$host
   )
   [string[]]$instances = @()
   foreach( $id in $global:all_serverids ) {
     $hn = $global:cuconfig.$id.hostname
     if($hn -eq $host) {
        $instance_names = $global:cuconfig.$id.mssql_instancenames
        foreach($i in $instance_names) {
          $instances += $i
        }
        break
     }
   }
   return [string[]]$instances
}
Export-ModuleMember -function Find-InstanceNames


function Stop-CopperEggMonitor {
  if( $global:CopperEggJobs -eq $null ) {
    Write-CuEggLog "No jobs found"
  }
  else {
    foreach( $job in $global:CopperEggJobs ) {
      stop-job -Id $job.Id
      remove-job -Id $job.Id
    }
  }
}
Export-ModuleMember -function Stop-CopperEggMonitor

function Remove-AllCopperEgg {
  $Err = $null
  $result = remove-module Start-CopperEggMonitor -ErrorAction SilentlyContinue  -ErrorVariable Err
  $result = remove-module UserDefined -ErrorAction SilentlyContinue  -ErrorVariable Err
  $result = remove-module Initialize-MetricGroups -ErrorAction SilentlyContinue  -ErrorVariable Err
  $result = remove-module Initialize-Dashboards -ErrorAction SilentlyContinue  -ErrorVariable Err
  $result = remove-module CopperEgg -ErrorAction SilentlyContinue  -ErrorVariable Err
}
Export-ModuleMember -function Remove-AllCopperEgg

# parse the config.yml file
[string]$fullpath = $global:mypath + '\config.yml'
if((Test-Path $fullpath) -eq $True) {
  $global:cuconfig = Get-Yaml -FromFile $fullpath
  if ($global:cuconfig -eq $null) {
    Write-CuEggLog "Found $fullpath; yaml parse failed"
    Write-CuEggLog "Please create a valid config.yml file"
    exit
  }
} else {
  Write-CuEggLog "$fullpath; not found"
  Write-CuEggLog "Please create a config.yml file in $global:mypath"
  exit
}
$global:apikey       = $global:cuconfig.copperegg.apikey
$global:frequency    = $global:cuconfig.copperegg.frequency
$global:local_remote = $global:cuconfig.copperegg.local_remote
Write-CuEggLog "global:frequency is $global:frequency"

# validate the apikey
if($global:apikey -eq $null) {
  Write-CuEggLog "Please add a valid CopperEgg apikey to your config.yml"
  exit
}
# validate the server list in config.yml
Write-CuEggLog "Scanning server list"
$srvrs = $global:cuconfig.copperegg.servers
foreach( $id in  $srvrs ) {
  $global:all_serverids += $id
  # check that each serverid has an associated server def
  $sdef = $global:cuconfig.$id
  if( $sdef -eq $null) {
    Write-CuEggLog "Invalid config.yml: no definition for server $id"
    exit
  }
  # check that each server that includes the mssql metric group also
  # has an one or more mssql instances names
  $smgroups = $sdef.metricgroups
  if($smgroups -contains 'MS_MSSQL'){
    if($sdef.mssql_instancenames -ne $null){
      $instances = $sdef.mssql_instancenames
      if($instances.length -eq 0){
        Write-CuEggLog "Invalid config.yml: no mssql_instancenames included for server $id"
        exit
      }
    } else {
      Write-CuEggLog "Invalid config.yml: mssql_instancenames is not included for server $id"
      exit
    }
  }
}
# validate the metricgroup list in config.yml
Write-CuEggLog "Scanning metricgroups list"
$mgroups = $global:cuconfig.copperegg.metricgroups
foreach( $id in  $mgroups ) {
  $global:all_metricgroupids += $id
  # check that each metricgroupid has an associated metricgroup def
  $mdef = $global:cuconfig.$id
  if( $mdef -eq $null) {
    Write-CuEggLog "Invalid config.yml: no definition for metric group $id"
    exit
  }
}
# validate the  dashboards list in config.yml
Write-CuEggLog "Scanning dashboards list"
$dashes = $global:cuconfig.copperegg.dashboards
foreach( $id in  $dashes ) {
  $global:all_dashboardids += $id
  # check that each dashboardid has an associated dashboard def
  $mdef = $global:cuconfig.$id
  if( $mdef -eq $null) {
    Write-CuEggLog "Invalid config.yml: no definition for dashboard $id"
    exit
  }
}
if(($global:local_remote -eq 'local') -or ($global:local_remote -eq 'remote') -or ($global:local_remote -eq 'all')){
  Write-CuEggLog "local_remote flag specified is $global:local_remote"
} else {
  Write-CuEggLog "Invalid or no local_remote flag specified"
  Write-CuEggLog "Defaulting to local"
  $global:local_remote = 'local'
}
