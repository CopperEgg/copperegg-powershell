#
# Start-DebugMonitor.ps1 does what Start-CopperEggMonitor does, but in the foreground, and only once.
#
# Copyright (c) 2012,2013 CopperEgg Corporation. All rights reserved.
#

$global:usermod_loaded = 0

function Start-DebugMonitor {
  $mhj = $global:master_hash | ConvertTo-Json -Depth 5
  [string]$mhj = $mhj
  [string]$apikey = $global:apikey
  [string]$mypath = $global:mypath

  While($True) {
    foreach( $id in $global:all_metricgroupids ) {
      $gn = $global:cuconfig.$id.group_name
      $mg = Find-MetricGroup $gn
      if($mg -ne $null) {
        Write-CuEggLog "foreach thing $id in all_metricgroupids, with group_name $gn, Find-Metricgroup returned"
        $mg

        $groupcfg = $mg.gcfg
        $freq = $groupcfg.frequency
        [string[]]$hosts = $mg.hosts
        [string]$group_name = $mg.name
        if( $hosts.length -gt 0) {

          if($id.StartsWith("MS_")) {
            Write-CuEggLog "MS Perf Counter Service $id, group name $gn"
            if($id -eq 'MS_MSSQL'){
              # ms sql has to be handled separately to support multiple instance names per host
              $hostmap = $mg.host_map

              Write-CuEggLog "Monitoring $gn,  Hosts to monitor:"
              $hosts
              $metric_data = @{}
              [int]$epochtime = 0
              $unixEpochStart = new-object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
              $newhash = $mhj | ConvertFrom-Json

              foreach($h in $hosts) {
                $hh_array = $hostmap.$h
                foreach($hh in $hh_array){
                  $hh
                  $iname = $hh.instancename
                  Write-CuEggLog "instance name is $iname"
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
                      Write-CuEggLog "Sample path is $path"
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
                      Write-CuEggLog "cepath is $cepath"
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
                    Write-CuEggLog "sending sample data: server is $h; instance is $iname, uri is $uri; json_data is $data_json"
                    $rslt = $req.UploadString($uri, $data_json)
                  }
                }
              }
            } else {
              # Windows Performance Counter Service, NOT MS_MSSQL
              Write-CuEggLog "Monitoring $gn,  Hosts to monitor:"
              $hosts

              $metric_data = @{}
              [int]$epochtime = 0
              $unixEpochStart = new-object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
              $newhash = $mhj | ConvertFrom-Json
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
                    Write-CuEggLog "Sample path is $path"
                    if ($path.StartsWith('\\') -eq 'True'){
                      [int]$off = $path.IndexOfAny('\', 2)
                      [string]$path = $path.Substring($off).ToString()
                    }
                    if ($path.StartsWith('\\') -eq 'True'){
                      [string]$path = $path.Substring(1).ToString()
                    }
                    Write-CuEggLog "path is $path"
                    $metric_data.Add( ($newhash | Select-Object $path).$path.ToString(), $sample.CookedValue )
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
                  Write-CuEggLog "sending sample data: server is $h; uri is $uri; json_data is $data_json"
                  $rslt = $req.UploadString($uri, $data_json)
                }
              }
            }
          } else {
            # user-defined metrics
            # NOTE: can only be used on the local machine
            if( $global:usermod_loaded -eq 0){
              [string]$fullpath = $mypath + '\UserDefined.psm1'
              import-module $fullpath
              $global:usermod_loaded = 1
            }
            Write-CuEggLog "Monitoring $gn,  Hosts to monitor:"
            $hosts
            $metric_data = @{}
            [int]$epochtime = 0
            $unixEpochStart = new-object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
            $newhash = $mhj | ConvertFrom-Json
            foreach($h in $hosts) {
              [string[]]$ce_custom = $mg.CE_Variables
              $groupcfg = $mg.gcfg
              $freq = $groupcfg.frequency 
              $metric_data = $null
              $metric_data = new-object @{}

              foreach($var in $ce_custom){
                $fxn = ($newhash | Select-Object $var).$var.ToString()
                $fxnrslt  = & $fxn
                [DateTime]$utc = [System.DateTime]::Now.ToUniversalTime()
                $epochtime=($utc - $unixEpochStart).TotalSeconds
                $metric_data.Add($var, $fxnrslt)
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
          }
        }
      }
    }
    Start-Sleep -s 15
  }
}
