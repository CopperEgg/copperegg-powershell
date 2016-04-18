#
#    Start-CustomCopperEggJob.ps1:	 This script represents a background task, and is kicked-off from Start-CopperEggMonitor.
#
#	This script does not rely on Get-Counter ... for each monitored metric, this routine expects a variable name and a function that can be called
#	to retrieve the value for that variable.
#
# Copyright (c) 2012-2014 IDERA. All rights reserved.
#
#
param([string[]]$CE_Variables,[string]$group_name,[string]$mhj,[string]$apikey,[string[]]$hosts,[string]$mypath, $mg)
function Start-CustomCopperEggJob {
param(
  [string[]]$CE_Variables,
  [string]$group_name,
  [string]$mhj,
  [string]$apikey,
  [string[]]$hosts,
  [string]$mypath,
  $mg
  )
  [string]$fullpath = "$mypath\UserDefined.psm1"
  import-module $fullpath
  $metric_data = @{}
  $newhash = $mhj | ConvertFrom-Json
  $groupcfg = $mg.gcfg
  $freq = $groupcfg.frequency
  [string[]]$hosts = $mg.hosts
  [string]$group_name = $mg.name

  While($True) {
    $metric_data = $null
    $metric_data = new-object @{}
    foreach($h in $hosts) {
      [string[]]$ce_custom = $mg.CE_Variables
      $metric_data = $null
      $metric_data = new-object @{}
      $EpochSecs=[int][double]::Parse($(Get-Date -date (Get-Date).ToUniversalTime()-uformat %s))

      foreach($var in $ce_custom){
        $fxn = ($newhash | Select-Object $var).$var.ToString()
        $fxnrslt  = & $fxn
        $metric_data.Add($var, $fxnrslt)
      }

      $apicmd = '/revealmetrics/samples/' + $group_name + '.json'
      $payload = New-Object PSObject -Property @{
        "timestamp"=$EpochSecs;
        "identifier"=[string]$h;
        "values"=$metric_data
      }
      $data = $payload
      $uri = 'https://api.staging.cuegg.net/v2' + $apicmd
      $authinfo = $apikey + ':U'
      $auth = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($authinfo))
      $req = New-Object System.Net.WebClient
      $req.Headers.Add('Authorization', $auth )
      $req.Headers.Add('Accept', '*/*')
      $req.Headers.Add("user-agent", "PowerShell")
      [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
      [System.Net.ServicePointManager]::Expect100Continue = $false
      $req.Headers.Add('Content-Type', 'application/json')
      $data_json = $data | ConvertTo-JSON  -compress -Depth 5
      Try
      {
        $rslt = $req.UploadString($uri, $data_json)
      }
      Catch [system.exception]
      {
        Write-CuEggLog "Exception in Posting Samples, Custom: $($_.Exception.GetType().Name) - $($_.Exception.Message)"
        Write-CuEggLog "uri : $uri , data_json :  $data_json"
      }
    }
    Start-Sleep -s $freq
  }
}
Start-CustomCopperEggJob $CE_Variables $group_name $mhj $apikey $hosts $mypath $mg
