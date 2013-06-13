#
#    Start-CustomCopperEggJob.ps1:	 This script represents a background task, and is kicked-off from Start-CopperEggMonitor.
#
#	This script does not rely on Get-Counter ... for each monitored metric, this routine expects a variable name and a function that can be called
#	to retrieve the value for that variable.
#
# Copyright (c) 2012 CopperEgg Corporation. All rights reserved.
#
#
param([string[]]$CE_Variables,[string]$group_name,[string]$mhj,[string]$apikey,[string]$host,[string]$mypath, $mg)
function Start-CustomCopperEggJob {
param(
  [string[]]$CE_Variables,
  [string]$group_name,
  [string]$mhj,
  [string]$apikey,
  [string]$host,
  [string]$mypath,
  $mg
  )
  [string]$fullpath = $mypath + '\UserDefined.psm1'
  import-module $fullpath
  $metric_data = @{}
  [int]$epochtime = 0
  $unixEpochStart = new-object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
  $newhash = $mhj | ConvertFrom-Json
  While($True) {
    $metric_data = $null
    $metric_data = new-object @{}

    foreach($var in $CE_Variables){
      $fxn = ($newhash | Select-Object $var).$var.ToString()
      $fxnrslt  = & $fxn
      [DateTime]$utc = [System.DateTime]::Now.ToUniversalTime()
      $epochtime=($utc - $unixEpochStart).TotalSeconds
      $metric_data.Add($var, $fxnrslt)
    }
    $apicmd = '/revealmetrics/samples/' + $group_name + '.json'
    $payload = New-Object PSObject -Property @{
      "timestamp"=$epochtime;
      "identifier"=[string]$host;
      "values"=$metric_data
    }
    $data = $payload
    $uri = 'https://api.copperegg.com/v2' + $apicmd
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
    $rslt = $req.UploadString($uri, $data_json)
    Start-Sleep -s $freq
  }
}
Start-CustomCopperEggJob $CE_Variables $group_name $mhj $apikey $host $mypath $mg
