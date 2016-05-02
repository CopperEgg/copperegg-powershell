#
# Start-DebugMonitor.ps1 does what Start-CopperEggMonitor does, but in the foreground, and is hard-coded to 15 seconds.
# Run Start-DebugMonitor instead of Start-CopperEggMonitor when you first get started, or when you
# make serious changes to your config.yml.
#
# Copyright (c) 2012-2014 IDERA. All rights reserved.
#

$global:usermod_loaded = 0

function Start-DebugMonitor {
  $mhj = $global:master_hash | ConvertTo-Json -compress -Depth 5
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
                    $EpochSecs=[int][double]::Parse($(Get-Date -date (Get-Date).ToUniversalTime()-uformat %s))
                    $payload = New-Object PSObject -Property @{
                      "timestamp"=$EpochSecs;
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
                    $data_json = $data | ConvertTo-JSON -compress -Depth 5
                    Write-CuEggLog "sending sample data: server is $h; instance is $iname, uri is $uri; json_data is $data_json"
                    $rslt = $req.UploadString($uri, $data_json)
                  }
                }
              }
            } elseif ($id -eq 'MS_AzureSQL') {

              $metric_data = @{}
              foreach($h in $hosts) {

                $Query = "SELECT counter_name, cntr_value FROM sys.dm_os_performance_counters WHERE
          counter_name in ('Cache Hit Ratio Base', 'Checkpoint pages/sec',
          'Page life expectancy', 'Processes blocked', 'Lock Waits/sec',
          'Page Splits/sec', 'Batch Requests/sec', 'SQL Re-Compilations/sec',
          'SQL Compilations/sec', 'Active parallel threads', 'Active requests',
          'Active Transactions', 'Backup/Restore Throughput/sec', 'CPU usage %',
          'Blocked tasks', 'Cache Object Counts', 'Dropped Messages Total',
          'Errors/sec', 'Free Memory (KB)', 'Number of Deadlocks/sec',
          'Open Connection Count', 'Page lookups/sec', 'Page reads/sec',
          'Page Splits/sec', 'Page writes/sec', 'Queued requests',
          'Transaction Delay', 'Transaction ownership waits', 'Transactions',
          'Write Transactions/sec');"


                $user_pass  = Find-UserNamePassword $h
                $auth = @{Username = $user_pass['username'] ; Password = $user_pass['password']}
                $samples = Invoke-Sqlcmd -Query $Query -ServerInstance $h @Auth

                Foreach ($sample in  $samples) {
                  $metric_data.Set_Item($sample.counter_name.trim(), $sample.cntr_value)
                }
                $EpochSecs=[int][double]::Parse($(Get-Date -date (Get-Date).ToUniversalTime()-uformat %s))
                $payload = @{
                  identifier             = [string]$h;
                  timestamp              = $EpochSecs
                  values                 = @{
                    'Cache_Hit_Ratio_Base' = $metric_data['Cache Hit Ratio Base']
                    'Checkpoint_Pages_per_sec' = $metric_data['Checkpoint pages/sec']
                    'Page_Life_Expectancy' = $metric_data['Page life expectancy']
                    'Processes_Blocked' = $metric_data['Processes blocked']
                    'Lock_waits_per_sec' = $metric_data['Lock Waits/sec']
                    'Page_Splits_per_sec' = $metric_data['Page Splits/sec']
                    'Batch_Requests_per_sec' = $metric_data['Batch Requests/sec']
                    'SQL_Re-Compilations_per_sec' = $metric_data['SQL Re-Compilations/sec']
                    'SQL_Compilations_per_sec' = $metric_data['SQL Compilations/sec']
                    'Active_Parallel_Threads' = $metric_data['Active parallel threads']
                    'Active_Requests' = $metric_data['Active requests']
                    'Active_Transactions' = $metric_data['Active Transactions']
                    'Backup_Restore_Throughput_per_sec' = $metric_data['Backup/Restore Throughput/sec']
                    'Blocked_Tasks' = $metric_data['Blocked tasks']
                    'Cache_Object_Counts' = $metric_data['Cache Object Counts']
                    'CPU_Usage_Percent' = $metric_data['CPU usage %']
                    'Dropped_Messages_Total' = $metric_data['Dropped Messages Total']
                    'Errors_per_sec' = $metric_data['Errors/sec']
                    'Free_Memory' = $metric_data['Free Memory (KB)']
                    'Number_of_Deadlocks_per_Sec' = $metric_data['Number of Deadlocks/sec']
                    'Open_Connection_Count' = $metric_data['Open Connection Count']
                    'Page_Lookups_per_sec' = $metric_data['Page lookups/sec']
                    'Page_Reads_per_sec' = $metric_data['Page reads/sec']
                    'Page_Writes_per_sec' = $metric_data['Page writes/sec']
                    'Queued_Requests' = $metric_data['Queued requests']
                    'Transaction_Delay' = $metric_data['Transaction Delay']
                    'Transaction_Ownership_Waits' = $metric_data['Transaction ownership waits']
                    'Transactions' = $metric_data['Transactions']
                    'Write_Transactions_per_sec' = $metric_data['Write Transactions/sec']
                  }
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
                $data_json = $data | ConvertTo-JSON -compress -Depth 5
                Write-CuEggLog "sending sample data: server is $h; uri is $uri; json_data is $data_json"
                Try
                {
                  $rslt = $req.UploadString($uri, $data_json)
                }
                Catch [system.exception]
                {
                  Write-CuEggLog "Exception caught: $($_.Exception.GetType().Name) - $($_.Exception.Message)"
                  Write-CuEggLog "data : $data , data-json :  $data_json"
                }
              }
            } else {
              # Windows Performance Counter Service, NOT MS_MSSQL
              Write-CuEggLog "Monitoring $gn,  Hosts to monitor:"
              $hosts

              $metric_data = @{}
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
                  $EpochSecs=[int][double]::Parse($(Get-Date -date (Get-Date).ToUniversalTime()-uformat %s))
                  $payload = New-Object PSObject -Property @{
                    "timestamp"=$EpochSecs;
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
                  $data_json = $data | ConvertTo-JSON -compress -Depth 5
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
                $metric_data.Add($var, $fxnrslt)
              }
              $apicmd = '/revealmetrics/samples/' + $group_name + '.json'
              $EpochSecs=[int][double]::Parse($(Get-Date -date (Get-Date).ToUniversalTime()-uformat %s))
              $payload = New-Object PSObject -Property @{
                "timestamp"=$EpochSecs;
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
              $data_json = $data | ConvertTo-JSON compress -Depth 5
              $rslt = $req.UploadString($uri, $data_json)
            }
          }
        }
      }
    }
    Start-Sleep -s 15
  }
}
