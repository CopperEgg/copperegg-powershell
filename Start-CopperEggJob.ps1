#
#    Start-CopperEggJob.ps1 : a minimal background monitoring job.
#
# Copyright (c) 2012,2013 CopperEgg Corporation. All rights reserved.
#
param([string[]]$MSCounters,[string]$group_name,[string]$mhj,[string]$apikey,[string[]]$hosts,[string]$mypath,$mg)
function Start-CopperEggJob {
param(
  [string[]]$MSCounters,
  [string]$group_name,
  [string]$mhj,
  [string]$apikey,
  [string[]]$hosts,
  [string]$mypath,
  $mg
  )
  $groupcfg = $mg.gcfg
  $freq = $groupcfg.frequency
  if($group_name -eq 'MS_SQL'){
    # ms sql has to be handled separately to support multiple instance names per host
    $hostmap = $mg.host_map

    $metric_data = @{}
    [int]$epochtime = 0
    $unixEpochStart = new-object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
    $newhash = $mhj | ConvertFrom-Json

    While($True) {
      foreach($h in $hosts) {
        $hh_array = $hostmap.$h
        foreach($hh in $hh_array){
          $iname = $hh.instancename
          [string[]]$MSCounters = $hh.mspaths
          [string[]]$result = $MSCounters.replace(",","`n")

          $metric_data = $null
          $metric_data = new-object @{}
          if($env:computername -eq $h) {
            $samples = Get-Counter -Counter $result
          } else {
            $samples = Get-Counter -ComputerName $h -Counter $result
          }
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
              if ($path.StartsWith('\\') -eq 'True'){
                [string]$path = $path.Substring(1).ToString()
              }
              [int]$off = $path.IndexOfAny(':', 1)
              $off += 1
              [string]$cepath = $path.Substring($off).ToString()
              $metric_data.Add( ($newhash | Select-Object $cepath).$cepath.ToString(), $sample.CookedValue )
            }
            $apicmd = '/revealmetrics/samples/' + $group_name + '.json'
            $payload = New-Object PSObject -Property @{
              "timestamp"=$epochtime;
              "identifier"=[string]$iname;
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
          }
        }
      }
      Start-Sleep -s $freq
    }
  } else {
    # Windows Performance Counter Service, NOT MS_MSSQL

    $metric_data = @{}
    [int]$epochtime = 0
    $unixEpochStart = new-object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
    $newhash = $mhj | ConvertFrom-Json

    While($True) {
      foreach($h in $hosts) {

        [string[]]$MSCounters = $mg.mspaths
        $groupcfg = $mg.gcfg
        $freq = $groupcfg.frequency
        [string[]]$result = $MSCounters.replace(",","`n")

        $metric_data = $null
        $metric_data = new-object @{}
        if($env:computername -eq $h) {
          $samples = Get-Counter -Counter $result
        } else {
          $samples = Get-Counter -ComputerName $h -Counter $result
        }
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
            if ($path.StartsWith('\\') -eq 'True'){
              [string]$path = $path.Substring(1).ToString()
            }
            $metric_data.Add( ($newhash | Select-Object $path).$path.ToString(), $sample.CookedValue )
          }
        }
        $apicmd = '/revealmetrics/samples/' + $group_name + '.json'
        $payload = New-Object PSObject -Property @{
          "timestamp"=$epochtime;
          "identifier"=[string]$h;
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
      }
      Start-Sleep -s $freq
    }
  }

}
Start-CopperEggJob $MSCounters $group_name $mhj $apikey $hosts $mypath $mg
