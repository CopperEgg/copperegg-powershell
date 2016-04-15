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
                     counter_name LIKE '%page life expectancy%' OR 
                     counter_name LIKE 'cache hit ratio%' OR
                     counter_name LIKE '%page splits%' OR
                     counter_name LIKE '%checkpoint pages%' OR
                     counter_name LIKE '%batch requests%' OR
                     counter_name LIKE '%open connection count%' OR
                     counter_name LIKE 'lock waits%' OR
                     counter_name LIKE '%processes blocked%' OR
                     counter_name LIKE '%sql compilations%' OR
                     counter_name LIKE '%sql re-compilations%';"

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
  Try
  {
    if($Username)
    {
      $auth = @{Username = $Username ; Password = $Password}
      if($Debug)
      {
        Write-Host "Instance $Instance is 'SQL Server' Authenticated"
      }
    }
    else
    {
      $auth=@{}
      if($Debug)
      {
        Write-Host "Instance $Instance is 'Windows' Authenticated"
      }
    }
    return Invoke-Sqlcmd -Query $Query -ServerInstance $Instance @Auth
  }
  Catch [system.exception]
  {
    Write-Log "Exception in getting data from SQL Server Instance: $($_.Exception.GetType().Name) - $($_.Exception.Message)"
    if ($Debug)
    {
      Write-Log "Exception name => $($_.Exception.GetType().Name) - $($_.Exception.Message), at line number $($_.InvocationInfo.ScriptLineNumber)"
      Write-Log "More information about error (if any) => $($error[0] | out-string)"
    }
  }
}

<# Custom method to process performance metrics and send only required performance metrics to 
   UCM API. Processing logic is simple, if there was a single value for a performance metric, it is
   forwarded as it is. If there are multiple values for a metric (say Page Splits), they are 
   averaged. For eg, two results for page splits are 20 and 30 respectively, then the value sent to 
   API is 25 ([20+30]/(2)). This calculation is handled by two hashes (DataHash and CounterHash). 
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
    timestamp              = Get-UnixTimestamp
    identifier             = $SystemIdentifier
    values                 = @{
      page_life_expectancy = $DataHash.Get_Item("Page Life Expectancy") / $CountHash.Get_Item("Page Life Expectancy")
      access_page_splits   = $DataHash.Get_Item("Page Splits/sec") / $CountHash.Get_Item("Page Splits/sec")
      cache_hit_ratio      = $DataHash.Get_Item("Cache Hit Ratio") / $CountHash.Get_Item("Cache Hit Ratio")
      checkpoint_pages     = $DataHash.Get_Item("Checkpoint pages/sec") / $CountHash.Get_Item("Checkpoint pages/sec")
      batch_requests       = $DataHash.Get_Item("Batch Requests/sec") / $CountHash.Get_Item("Batch Requests/sec")
      connections          = $DataHash.Get_Item("Open Connection Count") / $CountHash.Get_Item("Open Connection Count")
      lock_waits           = $DataHash.Get_Item("Lock waits") / $CountHash.Get_Item("Lock waits")
      proc_blocked         = $DataHash.Get_Item("Processes blocked") / $CountHash.Get_Item("Processes blocked")
      sql_compilations     = $DataHash.Get_Item("SQL Compilations/sec") / $CountHash.Get_Item("SQL Compilations/sec")
      sql_recompilations   = $DataHash.Get_Item("SQL Re-Compilations/sec") / $CountHash.Get_Item("SQL Re-Compilations/sec")
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
    Write-Log "ApiKey: $ApiKey, URI: $URI, data : $DataJson"
    if ($Debug)
    {
      Write-Log "Exception name => $($_.Exception.GetType().Name) - $($_.Exception.Message), at line number $($_.InvocationInfo.ScriptLineNumber)"
      Write-Log "More information about error (if any) => $($error[0] | out-string)"
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
