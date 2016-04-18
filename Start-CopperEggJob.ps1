#
#    Start-CopperEggJob.ps1 : a minimal background monitoring job.
#
# Copyright (c) 2012-2014 IDERA. All rights reserved.
#
param([string[]]$MSCounters,[string]$group_name,[string]$mhj,[string]$apikey,[string]$hostname,[string]$username,[string]$password,[string]$mypath,$mg)
function Start-CopperEggJob {
param(
  [string[]]$MSCounters,
  [string]$group_name,
  [string]$mhj,
  [string]$apikey,
  [string]$hostname,
  [string]$username,
  [string]$password,
  [string]$mypath,
  $mg
  )
  $groupcfg = $mg.gcfg
  $freq = $groupcfg.frequency
  if($group_name -eq 'MS_SQL'){
    # ms sql has to be handled separately to support multiple instance names per host
    $hostmap = $mg.host_map

    $metric_data = @{}
    $newhash = $mhj | ConvertFrom-Json

    While($True) {
        $hh_array = $hostmap.$hostname
        foreach($hh in $hh_array){
          $iname = $hh.instancename
          [string[]]$MSCounters = $hh.mspaths
          [string[]]$result = $MSCounters.replace(",","`n")

          $metric_data = $null
          $metric_data = new-object @{}
          if($env:computername -eq $hostname) {
            $samples = Get-Counter -Counter $result
          } else {
            $samples = Get-Counter -ComputerName $hostname -Counter $result
          }
          foreach($counter in $samples){
            $sample=$counter.CounterSamples[0]
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
        }
      Start-Sleep -s $freq
    }
  } elseif( $group_name -eq 'Azure_SQL' ){

    While($True) {
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

        $auth = @{Username = $username ; Password = $password}
        $samples = Invoke-Sqlcmd -Query $Query -ServerInstance $hostname @Auth

        $metric_data      = @{}
        Foreach ($sample in  $samples) {
          $CounterName = $sample.counter_name.trim()
          $metric_data.Set_Item($CounterName, $sample.cntr_value)
        }

        $apicmd = '/revealmetrics/samples/' + $group_name + '.json'
        $EpochSecs=[int][double]::Parse($(Get-Date -date (Get-Date).ToUniversalTime()-uformat %s))
        $payload = @{
          identifier             = [string]$hostname;
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
        $data_json = $payload | ConvertTo-JSON -compress -Depth 5
        Try
        {
          Write-CuEggLog "Sending data to api $data_json"
          $rslt = $req.UploadString($uri, $data_json)
        }
        Catch [system.exception]
        {
          Write-CuEggLog "Exception caught: $($_.Exception.GetType().Name) - $($_.Exception.Message)"
          Write-CuEggLog "data : $data , data-json :  $data_json"
        }
      Start-Sleep -s $freq
    }
  } else {
    # Windows Performance Counter Service, NOT MS_MSSQL

    $metric_data = @{}
    $newhash = $mhj | ConvertFrom-Json

    While($True) {
        [string[]]$MSCounters = $mg.mspaths
        $groupcfg = $mg.gcfg
        $freq = $groupcfg.frequency
        [string[]]$result = $MSCounters.replace(",","`n")

        $metric_data = $null
        $metric_data = new-object @{}
        if($env:computername -eq $hostname) {
          $samples = Get-Counter -Counter $result
        } else {
          $samples = Get-Counter -ComputerName $hostname -Counter $result
        }
        foreach($counter in $samples){
          $sample=$counter.CounterSamples[0]
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
        $EpochSecs=[int][double]::Parse($(Get-Date -date (Get-Date).ToUniversalTime()-uformat %s))
        $payload = New-Object PSObject -Property @{
          "timestamp"=$EpochSecs;
          "identifier"=[string]$hostname;
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
        $data_json = $data | ConvertTo-JSON -compress -Depth 5
        Try
        {
          $rslt = $req.UploadString($uri, $data_json)
        }
        Catch [system.exception]
        {
          Write-CuEggLog "Exception in Posting Samples: $($_.Exception.GetType().Name) - $($_.Exception.Message)"
          Write-CuEggLog "uri : $uri , data-json :  $data_json"
        }
      Start-Sleep -s $freq
    }
  }

}
Start-CopperEggJob $MSCounters $group_name $mhj $apikey $hostname $username $password $mypath $mg
