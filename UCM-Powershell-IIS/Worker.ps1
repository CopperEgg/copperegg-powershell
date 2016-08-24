<# Below is a declaration of global variables used across the file (names are self explanatory) #>

$Apikey           = ''

$ApiServer        = ''

$MetricGroup      = ''

$SleepTime        = 0

$Instance         = ''

$Username         = ''

$Password         = ''

$Hostname         = ''

$SystemIdentifier = ''

$QueryMetrics     = @(
  '\Web Service(default web site)\Bytes Received/sec', '\Web Service(default web site)\Bytes Sent/sec',
  '\Web Service(default web site)\CGI Requests/sec', '\Web Service(default web site)\Current Anonymous Users',
  '\Web Service(default web site)\Current CGI Requests', '\Web Service(default web site)\Current Connections',
  '\Web Service(default web site)\Current ISAPI Extension Requests', '\Web Service(default web site)\Current NonAnonymous Users',
  '\Web Service(default web site)\ISAPI Extension Requests/sec', '\Web Service(default web site)\Lock Requests/sec',
  '\Web Service(default web site)\Locked Errors/sec', '\Web Service(default web site)\Maximum CGI Requests',
  '\Web Service(default web site)\Maximum Connections', '\Web Service(default web site)\Maximum ISAPI Extension Requests',
  '\Web Service(default web site)\NonAnonymous Users/sec', '\Web Service(default web site)\Not Found Errors/sec',
  '\Web Service(default web site)\Service Uptime'
  );

# Initializing this variable here, before sending each request, the variable is
# initialized again otherwise request fails after sometime
$Request = New-Object System.Net.WebClient

$LogFile = "$env:programfiles\UCM-Powershell\IIS\ucm-metrics.log"

$SamplesCounter   = 1
$DataHash         = @{}
$CountHash        = @{}

function Write-log($Message)
{
  $TimeStamp =  Get-Date -Format "yyyy-MM-dd hh:mm:ss"
  $ProcessId = $([System.Diagnostics.Process]::GetCurrentProcess().Id)
  Add-Content $LogFile -value "$TimeStamp MSIIS-Powershell-Agent pid:$ProcessId> $Message"
}

function Get-UnixTimestamp
{
  return $ED=[Math]::Floor([decimal](Get-Date(Get-Date).ToUniversalTime()-uformat "%s"))
}

function Initialize-VariablesFromConfig($Config)
{
  $script:Instance         = [string]$Config.InstanceName.trim()
  $script:SystemIdentifier = [string]$Config.SystemIdentifier.trim()
  $script:Username         = [string]$Config.Username.trim()
  $script:Password         = [string]$Config.Password.trim()
  $script:Hostname         = [string]$Config.Hostname.trim()

  Write-Log "Parsed Argument from config ==> IIS Instance name : '$Instance'"
  Write-Log "Parsed Argument from config ==> IIS Hostname : '$Hostname'"
  Write-Log "Parsed Argument from config ==> System's Unique Name : '$SystemIdentifier'"

}

function Initialize-AuthAndHeaders
{
  $script:Request = New-Object System.Net.WebClient
  $AuthInfo = $ApiKey + ':U'
  $AuthObject = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($AuthInfo))
  $script:Request.Headers.Add('Authorization', $AuthObject)
  $script:Request.Headers.Add('Accept', '*/*')
  $script:Request.Headers.Add("User-Agent", "PowerShell")
  $script:Request.Headers.Add('Content-Type', 'application/json')
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
  [System.Net.ServicePointManager]::Expect100Continue = $false
}

function Process-PerformanceMetrics($samples)
{
  $metric_data = new-object @{}

  foreach($counter in $samples){
    foreach($sample in $counter.CounterSamples){
      [string]$path = $sample.Path.ToString()
      if ($path.StartsWith('\\') -eq 'True'){
        [int]$off = $path.IndexOfAny('\', 2)
        [string]$path = $path.Substring($off).ToString()
      }
      if ($path.StartsWith('\\') -eq 'True'){
        [string]$path = $path.Substring(1).ToString()
      }
      [int]$off = $path.IndexOfAny('\', 1)
      [string]$cepath = $path.Substring($off+1).ToString()
      $metric_data.Add( $cepath, $sample.CookedValue )
    }
  }

  $sample_data = @{
    timestamp  = Get-UnixTimestamp
    identifier = $SystemIdentifier
    values     = $metric_data
  }

  return $sample_data
}

function Get-PerformanceMetrics
{
  Try
  {
    if($env:computername -eq $Hostname) {
      $samples = Get-Counter -Counter $QueryMetrics
    } else {
      $samples = Get-Counter -ComputerName $Hostname -Counter $QueryMetrics
    }
    return $samples
  }
  Catch [system.exception]
  {
    Write-log "Exception in getting data from: $($_.Exception.GetType().Name) - $($_.Exception.Message)"
    Write-log "Exception name => $($_.Exception.GetType().Name) - $($_.Exception.Message), at line number $($_.InvocationInfo.ScriptLineNumber)"
    Write-log "More information about error (if any) => $($error[0] | out-string)"
  }
}

function Send-PerformanceMetrics($Data)
{
  $URI = "$ApiServer/v2/revealmetrics/samples/$MetricGroup.json"
  Initialize-AuthAndHeaders
  $DataJson = $Data | ConvertTo-JSON -compress -Depth 5
  Try
  {
    $Result = $script:Request.UploadString($URI, $DataJson)
    $StatusCode = $($script:Request.ResponseHeaders.Item('status'))
    if($StatusCode -ne "200 OK")
    {
      Write-Log "Failed sending the sample to Uptime Cloud Monitor. The response code was not 200."
      Write-Log "More information : Response code : '$StatusCode', Request result : '$Result'"
    }
  }
  Catch [system.exception]
  {
    Write-Log "Exception in sending metric information to Uptime Cloud Monitor for instance $InstanceName"
    Write-Log "Exception name => $($_.Exception.GetType().Name) - $($_.Exception.Message), at line number $($_.InvocationInfo.ScriptLineNumber)"
    Write-Log "More information about error (if any) => $($error[0] | out-string)"
  }

}

Write-log "Starting worker job "

# Parsing parameters from args which is a complex array (passed by parent script)
[string]$Apikey = $args[2]
[string]$ApiServer = $args[3]
[string]$MetricGroup = $args[4]
[string]$SleepTime = $args[5]
[string]$BasePath = $args[6]

Write-Log "Parsed Argument from config ==> Apikey : '$ApiKey'"
Write-Log "Parsed Argument from config ==> API Server : '$ApiServer'"
Write-Log "Parsed Argument from config ==> Metric Group name : '$MetricGroup'"
Write-Log "Parsed Argument from config ==> Monitoring Frequency : '$SleepTime'"

Initialize-VariablesFromConfig($args[1])

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
    Write-log "Error getting/sending performance metrics for instance $Instance"
    $NormalizedSleepTime = 5
  }

  if($Debug)
  {
    Write-Log "Sleeping for $NormalizedSleepTime Seconds, Time for getting metrics and uploading them was seconds."
  }

  Start-Sleep -Seconds $SleepTime
}
