$root = $PSScriptRoot

. $root\Utils.ps1

<# Custom method to Create a metric group based on parameters passed to the script. This is done
   everytime when the parent script is started. If metric group already exists, nothing is done.
   Arguments : ApiServer (Address of API Server, kept flexible for testing on dev/staging env)
               Apikey (Apikey of user using which metric group is created and samples are sent)
               GroupName (Name of the metric group)
               GroupLabel (Label of the metric group)
               MonitoringFrequency (Frequency on which this metric group will be monitored)
#>
function Create-MetricGroup([string]$ApiServer, [string]$ApiKey, [string]$ServiceName, [string]$GroupName, [string]$GroupLabel, [string]$MonitoringFrequency)
{
  $Request = New-Object System.Net.WebClient
  $URI = "$ApiServer/v2/revealmetrics/metric_groups"
  $AuthInfo = $ApiKey + ':U'
  $AuthObject = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($AuthInfo))
  $Request.Headers.Add('Authorization', $AuthObject)
  $Request.Headers.Add('Accept', '*/*')
  $Request.Headers.Add("User-Agent", "PowerShell")
  $Request.Headers.Add('Content-Type', 'application/json')
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
  [System.Net.ServicePointManager]::Expect100Continue = $false

  # Get the json, make a hashtable out of it, modify the requried parameters and convert back to JSON
  $DataJson = Get-Content -Raw -Path "$PSScriptRoot\metric_group.json" | ConvertFrom-JSON
  $ConvertedJson = $DataJson.$ServiceName
  $ConvertedJson.name = $GroupName
  $ConvertedJson.label = $GroupLabel
  $ConvertedJson.frequency = $MonitoringFrequency
  $DataJson = $ConvertedJson | ConvertTo-JSON -Depth 10

  Write-Log "Updated DataJson parameters from config : $DataJson"
  Try
  {
    $Result = $Request.UploadString($URI, $DataJson)
    $StatusCode = $($Request.ResponseHeaders.Item('status'))
    Write-Log "Succesfully created metric group on Uptime Cloud Monitor [$StatusCode]"
    if($StatusCode -ne "200 OK")
    {
      Write-Log "Failed while creating metric-group for $($ConvertedJson.name). The response code was not 200."
      Write-Log "More information : Response code : '$StatusCode', Request result : '$Result'"
    }
  }
  Catch [system.exception]
  {
    Write-Log "Exception in sending request for creating metric-group on Uptime Cloud Monitor for $($ConvertedJson.name)"
    Write-Log "Exception name => $($_.Exception.GetType().Name) - $($_.Exception.Message), at line number $($_.InvocationInfo.ScriptLineNumber)"
    Write-Log "More information about error (if any) => $($error[0] | out-string)"
    Write-Log "URI => $URI"
  }
}
