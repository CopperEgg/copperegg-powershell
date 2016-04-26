# Utils.ps1 : has some utility functions which are used by other files

# LogFile variable, used in Write-log function to write all the log content to log file
$LogFile = "$PSScriptRoot\ucm-metrics.log"

<# Custom method to write string content to file.
   Also appends current timestamp and process id of current process before message.
   Arguments : Message (String content to be written to the file)
#>
function Write-Log($Message)
{
  $TimeStamp =  Get-Date -Format "yyyy-MM-dd hh:mm:ss"
  $ProcessId = $([System.Diagnostics.Process]::GetCurrentProcess().Id)
  Add-Content $LogFile -value "$TimeStamp SQL-Powershell-Agent pid:$ProcessId> $Message"
}

<# Custom method to parse config.xml file (configuration settings for script)
   First it checks if file exists, if it does then contents are parsed as XML otherwise error(s)
   are returned
   Arguments : filename (Path of file)
#>
function Parse-Config($filename)
{
  Try
  {
    <# -EA Stop is important switch here because by default, FileNotFoundException isn't
        catched by powershell and it terminates the script. We also terminate the script but in a
        cleaner way, i.e. after logging proper error into the file
    #>
    $file = Get-Item -Path $filename -EA Stop
    if ($file.Exists)
    {
      return [xml] ( Get-Content -Path $filename )
    }
    else
    {
      Write-Log "The configuration file "$filename" does not exist. Exiting script"
      exit
    }
  }
  Catch [system.exception]
  {
    Write-Log "Cannot load configuration file : $filename"
    Write-Log "Exception name => $($_.Exception.GetType().Name) - $($_.Exception.Message), at line number $($_.InvocationInfo.ScriptLineNumber)"
    Write-Log "More information about error (if any) => $($error[0] | out-string)"
    exit
  }
}

$filename = "$PSScriptRoot"+"\config.xml"

# Parse the config file. This variable is also used by other files which import Utils.ps1
$Config = Parse-config($filename)

# Get common parameters from the file
[string]$ApiKey = $Config.Settings.UptimeCloudMonitor.Apikey.trim()
[string]$ApiServer = $Config.Settings.UptimeCloudMonitor.ApiServer.trim()
