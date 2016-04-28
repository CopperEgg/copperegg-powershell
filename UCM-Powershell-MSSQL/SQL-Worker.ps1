<# This is a worker thread process called by UCM-SQL-Monitor.ps1. Below is a declaration
   of global variables used across the file (names are self explanatory)
#>

$Apikey           = ''

$ApiServer        = ''

$MetricGroup      = ''

$SleepTime        = 0

$Instance         = ''

$Username         = ''

$Password         = ''

$Hostname         = ''

$SystemIdentifier = ''

$Query            = "SELECT counter_name, cntr_value FROM sys.dm_os_performance_counters WHERE
                     counter_name = 'active parallel threads' OR
                     counter_name = 'active requests' OR
                     counter_name = 'active transactions' OR
                     counter_name = 'backup/restore throughput/sec' OR
                     counter_name = 'batch requests/sec' OR
                     counter_name = 'blocked tasks' OR
                     counter_name = 'cache hit ratio' OR
                     counter_name = 'cache object counts' OR
                     counter_name = 'checkpoint pages/sec' OR
                     counter_name = 'cpu usage %' OR
                     counter_name = 'dropped messages total' OR
                     counter_name = 'errors/sec' OR
                     counter_name = 'free memory (kb)' OR
                     counter_name = 'lock waits' OR
                     counter_name = 'number of deadlocks/sec' OR
                     counter_name = 'open connection count' OR
                     counter_name = 'page life expectancy' OR
                     counter_name = 'page lookups/sec' OR
                     counter_name = 'page reads/sec' OR
                     counter_name = 'page splits' OR
                     counter_name = 'page splits/sec' OR
                     counter_name = 'page writes/sec' OR
                     counter_name = 'processes blocked' OR
                     counter_name = 'queued requests' OR
                     counter_name = 'sql compilations/sec' OR
                     counter_name = 'sql re-compilations/sec' OR
                     counter_name = 'transaction delay' OR
                     counter_name = 'transaction ownership waits' OR
                     counter_name = 'transactions' OR
                     counter_name = 'write transactions/sec'";

$Request = New-Object System.Net.WebClient

# LogFile path is hardcoded here because worker thread cannot read $PSScriptRoot Variable
$LogFile = "$env:programfiles\UCM-Powershell\ucm-metrics.log"

$Debug = $FALSE

$SamplesCounter   = 1

$DataHash         = @{}

$CountHash        = @{}

<# Same function as defined in Utils.ps1. It is copied here because worker process cannot import
   other files
#>
function Write-Log($Message)
{
  $TimeStamp =  Get-Date -Format "yyyy-MM-dd hh:mm:ss"
  $ProcessId = $([System.Diagnostics.Process]::GetCurrentProcess().Id)
  Add-Content $LogFile -value "$TimeStamp SQL-Powershell-Agent pid:$ProcessId> $Message"

}

# Returns unix timestamp of current time (Unix like timestamp = Seconds passed since Jan 1 1970)
function Get-UnixTimestamp
{
  return $ED=[Math]::Floor([decimal](Get-Date(Get-Date).ToUniversalTime()-uformat "%s"))
}

<# Custom method to parse required variables from config object given by parent process.
   Arguments : Config (The object holding all the required variables)
#>

function Initialize-VariablesFromConfig($Config)
{
  $script:Instance         = [string]$Config.InstanceName.trim()
  $script:SystemIdentifier = [string]$Config.SystemIdentifier.trim()
  $script:Username         = [string]$Config.Username.trim()
  $script:Password         = [string]$Config.Password.trim()
  $script:Hostname         = [string]$Config.Hostname.trim()

  if ($Debug)
  {
    Write-Log "Parsed Argument from config ==> Apikey : '$ApiKey'"
    Write-Log "Parsed Argument from config ==> API Server : '$ApiServer'"
    Write-Log "Parsed Argument from config ==> Metric Group name : '$MetricGroup'"
    Write-Log "Parsed Argument from config ==> Monitoring Frequency : '$SleepTime'"
    Write-Log "Parsed Argument from config ==> SQL Server Instance name : '$Instance'"
    Write-Log "Parsed Argument from config ==> SQL Server Username : '$Username'"
    Write-Log "Parsed Argument from config ==> SQL Server Password : '$Password'"
    Write-Log "Parsed Argument from config ==> SQL Server Hostname : '$Hostname'"
    Write-Log "Parsed Argument from config ==> System's Unique Name : '$SystemIdentifier'"
  }
}

<# Custom method to parse initialize request object from custom headers and authentication info
   Arguments : none
#>
function Initialize-AuthAndHeaders
{
  $AuthInfo = $ApiKey + ':U'
  $AuthObject = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($AuthInfo))
  $Request.Headers.Add('Authorization', $AuthObject)
  $Request.Headers.Add('Accept', '*/*')
  $Request.Headers.Add("User-Agent", "PowerShell")
  $Request.Headers.Add('Content-Type', 'application/json')
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
  [System.Net.ServicePointManager]::Expect100Continue = $false

  if($Debug)
  {
    Write-Log "Created request object with authentication info and headers $($Request | out-string)"
  }
}

<# Custom method to get performance metrics from the SQL instance based on type of authentication
   (Windows/SQL Server Authentication).
   For SQL Server authentication mode, we have username and password, while the Windows
   authentication mode works without username and password. So if username is blank, that means we
   are authenticating with 'Windows Authentication' mode, otherwise 'SQL Server Authentication' mode.
   Arguments : none
#>
function Get-PerformanceMetrics
{
  $ConnectionString = @{Query = $script:Query}

  if ($Username -ne "")
  {
    $ConnectionString.Add("Username", $script:Username)
    $ConnectionString.Add("Password", $script:Password)
  }

  if ($Hostname -ne "")
  {
    $ConnectionString.Add("Hostname", $script:Hostname)
  }

  if ($Instance -ne "")
  {
    $ConnectionString.Add("ServerInstance", $script:Instance)
  }

  Try
  {
    # Run query with available information and return result.
    return Invoke-Sqlcmd @ConnectionString
  }
  Catch [system.exception]
  {
    Write-Log "Exception in getting data from SQL Server Instance: $($_.Exception.GetType().Name) - $($_.Exception.Message)"
    Write-Log "Exception name => $($_.Exception.GetType().Name) - $($_.Exception.Message), at line number $($_.InvocationInfo.ScriptLineNumber)"
    Write-Log "More information about error (if any) => $($error[0] | out-string)"

  }
}
<# Custom method to return value after diving the summed value from the no. of times of value occurance
   If the value is present in hashmaps, it is calculated and sent.
   In case the value was not there, it might cause divide by zero or some arithmetic error because
   we are performing division operation here, so in that case exception is caught and 0 is sent.

  Arguments : $Metric (Particular metric for which value is required)

#>
function Get-PerformanceMetricValue($Metric)
{
  Try
  {
    return $DataHash.Get_Item($Metric) / $CountHash.Get_Item($Metric)
  }
  Catch [system.exception]
  {
    return 0
  }
}

<# Custom method to process performance metrics and send only required performance metrics to
   UCM API. Processing logic is simple, if there was a single value for a performance metric, it is
   forwarded as it is. If there are multiple values for a metric (say Page Splits), they are
   averaged. For eg, two results for page splits are 20 and 30 respectively, then the value sent to
   API is 25 ([20+30]/(2)). This calculation is handled by two hashes (DataHash and CountHash).
   DataHash stores the added data (like 20+30 = 50 for Page Splits) and counter hash stores no. of
   times that value was in the QueryResult (1+1 = 2 for Page Splits).
   At thh end, the method returns Data JSON for the sample which can be sent to UCM API.

   Arguments : $QueryResult (Variable holding result of SQL query which contains all the metrics)
#>
function Process-PerformanceMetrics($QueryResult)
{
  if ($Debug)
  {
    Write-Log "Performance metrics from Instance $script:Instance before aggregation $($QueryResult | out-string)"
  }
  Foreach ($Row in  $QueryResult)
  {
    $CounterName = $Row.counter_name.trim()
    $CounterValue = $Row.cntr_value
    if($CounterName.equals("Cache Hit Ratio Base") -or $CounterName.equals("Lock Waits/sec"))
    {
      continue
    }
    if($DataHash.ContainsKey($CounterName))
    {
      $OldData = $DataHash.Get_Item($CounterName)
      $DataHash.Set_Item($CounterName, $OldData + $CounterValue)

      $OldCount = $CountHash.Get_Item($CounterName)
      $CountHash.Set_Item($CounterName, $OldCount + 1)
    }
    else
    {
      $DataHash.Set_Item($CounterName, $CounterValue)
      $CountHash.Set_Item($CounterName, 1)
    }
  }

  $Data = @{
    timestamp                        = Get-UnixTimestamp
    identifier                       = $SystemIdentifier
    values                           = @{
      active_parallel_threads        = Get-PerformanceMetricValue("active parallel threads")
      active_requests                = Get-PerformanceMetricValue("active requests")
      active_transactions            = Get-PerformanceMetricValue("active transactions")
      backup_restore_throughput_sec  = Get-PerformanceMetricValue("backup/restore throughput/sec")
      batch_requests_sec             = Get-PerformanceMetricValue("batch requests/sec")
      blocked_tasks                  = Get-PerformanceMetricValue("blocked tasks")
      cache_hit_ratio                = Get-PerformanceMetricValue("cache hit ratio")
      cache_object_counts            = Get-PerformanceMetricValue("cache object counts")
      checkpoint_pages_sec           = Get-PerformanceMetricValue("checkpoint pages/sec")
      cpu_usage                      = Get-PerformanceMetricValue("cpu usage %")
      dropped_messages_total         = Get-PerformanceMetricValue("dropped messages total")
      errors_sec                     = Get-PerformanceMetricValue("errors/sec")
      free_memory                    = Get-PerformanceMetricValue("free memory (kb)")
      lock_wait                      = Get-PerformanceMetricValue("lock waits")
      number_of_deadlocks_sec        = Get-PerformanceMetricValue("number of deadlocks/sec")
      open_connection_count          = Get-PerformanceMetricValue("open connection count")
      page_life_expectancy           = Get-PerformanceMetricValue("page life expectancy")
      page_lookups_sec               = Get-PerformanceMetricValue("page lookups/sec")
      page_reads_sec                 = Get-PerformanceMetricValue("page reads/sec")
      page_splits_sec                = Get-PerformanceMetricValue("page splits/sec")
      page_writes_sec                = Get-PerformanceMetricValue("page writes/sec")
      processes_blocked              = Get-PerformanceMetricValue("processes blocked")
      queued_requests                = Get-PerformanceMetricValue("queued requests")
      sql_compilations_sec           = Get-PerformanceMetricValue("sql compilations/sec")
      sql_re_compilations_sec        = Get-PerformanceMetricValue("sql re-compilations/sec")
      transaction_delay              = Get-PerformanceMetricValue("transaction delay")
      transaction_ownership_waits    = Get-PerformanceMetricValue("transaction ownership waits")
      transactions                   = Get-PerformanceMetricValue("transactions")
      write_transactions_sec         = Get-PerformanceMetricValue("write transactions/sec")
    }
  }
  return $Data
}

<# Custom method to send metrics to UCM Api after processing my Process-PerformanceMetrics
   Arguments : $Data (Sample JSON with all the required fields)
#>
function Send-PerformanceMetrics($Data)
{
  $URI = "$ApiServer/v2/revealmetrics/samples/$MetricGroup.json"
  Initialize-AuthAndHeaders

  $DataJson = $Data | ConvertTo-JSON -compress -Depth 5
  Try
  {
    if($Debug)
    {
      Write-Log "Sending $script:SamplesCounter th sample."
      Write-Log "URI : $URI, Request JSON : $($DataJson)"
    }
    $Result = $Request.UploadString($URI, $DataJson)
    $StatusCode = $($Request.ResponseHeaders.Item('status'))
    if($StatusCode -ne "200 OK")
    {
      Write-Log "Failed sending the sample to Uptime Cloud Monitor. The response code was not 200."
      Write-Log "More information : Response code : '$StatusCode', Request result : '$Result'"
    }
    Write-Log "Sent $script:SamplesCounter th sample"
  }
  Catch [system.exception]
  {
    Write-Log "Exception in sending metric information to Uptime Cloud Monitor for instance $InstanceName"
    Write-Log "Exception name => $($_.Exception.GetType().Name) - $($_.Exception.Message), at line number $($_.InvocationInfo.ScriptLineNumber)"
    Write-Log "More information about error (if any) => $($error[0] | out-string)"

    if ($Debug)
    {
      Write-Log "ApiKey: $ApiKey, URI: $URI, data : $DataJson"
    }
  }
  $script:SamplesCounter++
}

<# Custom method to parse arguments as sent by parent script. This is used to turn on 'Debug' flag
   Arguments : none
#>
function Parse-CommandLineArguments()
{
  $arguments = $script:args -split " "
  Foreach ($arg in $arguments)
  {
    if($arg -eq '-Debug')
    {
      $script:Debug = $TRUE
      Write-Log "Debug mode ON"
    }
  }
}

Write-Log "Starting worker job "

# Parsing parameters from args which is a complex array (passed by parent script)
[string]$Apikey = $args[2]
[string]$ApiServer = $args[3]
[string]$MetricGroup = $args[4]
[string]$SleepTime = $args[5]

Parse-CommandLineArguments($args[0])
Initialize-VariablesFromConfig($args[1])


<# Main loop :
   1. Clears DataHash and CountHash on each iteration
   2. Gets metrics, processes and sends them. Notes time taken to do this entire thing.
   3. This time is then substracted from Monitoring Frequency and thread then sleeps for remaining
      time.
   4. If there is any problem in getting the metrics, the thread sleeps for 5 seconds before
      retrying, irrespective of time spent for quering in previous iteration
#>
while($TRUE)
{
  $StartTime = Get-UnixTimestamp

  $DataHash.Clear()
  $CountHash.Clear()
  $QueryResult = Get-PerformanceMetrics
  if($QueryResult)
  {
    $Data = Process-PerformanceMetrics($QueryResult)
    Send-PerformanceMetrics($Data)
    $EndTime = Get-UnixTimestamp
    $NormalizedSleepTime  = $SleepTime - ($EndTime - $StartTime)
  }
  else
  {
    Write-Log "Error getting/sending performance metrics for instance $Instance"
    $NormalizedSleepTime = 5
  }

  if($Debug)
  {
    Write-Log "Sleeping for $NormalizedSleepTime Seconds, Time for getting metrics and uploading them was $($EndTime - $StartTime) seconds"
  }

  Start-Sleep -Seconds $NormalizedSleepTime
}
