$root = $PSScriptRoot

. $root\Utils.ps1

function Create-Dashboard($ApiServer, $ApiKey, $ServiceName, $DashboardName)
{
  $Request = New-Object System.Net.WebClient
  $URI = "$ApiServer/v2/revealmetrics/dashboards"
  $AuthInfo = $ApiKey + ':U'
  $AuthObject = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($AuthInfo))
  $Request.Headers.Add('Authorization', $AuthObject)
  $Request.Headers.Add('Accept', '*/*')
  $Request.Headers.Add("User-Agent", "PowerShell")
  $Request.Headers.Add('Content-Type', 'application/json')
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
  [System.Net.ServicePointManager]::Expect100Continue = $false

  # Get the json, make a hashtable out of it, modify the requried parameters and convert back to JSON
  $DataJson = Get-Content -Raw -Path "$root\dashboard.json" | ConvertFrom-JSON
  $ConvertedJson = $DataJson.$ServiceName
  $ConvertedJson.name = $DashboardName
  $DataJson = $ConvertedJson | ConvertTo-JSON -Depth 10

########## metric_group_name  change to metric group name

  Write-Log "Updated DataJson parameters from config : $DataJson"
  Try
  {
    $Result = $Request.UploadString($URI, $DataJson)
    $StatusCode = $($Request.ResponseHeaders.Item('status'))
    if($StatusCode -ne "200 OK")
    {
      Write-Host "Failed while creating dashboard for $($ConvertedJson.name). The response code was not 200."
      Write-Log "Failed while creating dashboard for $($ConvertedJson.name). The response code was not 200."
      Write-Log "More information : Response code : '$StatusCode', Request result : '$Result'"
    }
  }
  Catch [system.exception]
  {
    Write-Log "Exception in sending request for creating dashbord on Uptime Cloud Monitor for $($ConvertedJson.name)"
    Write-Log "Exception name => $($_.Exception.GetType().Name) - $($_.Exception.Message), at line number $($_.InvocationInfo.ScriptLineNumber)"
    Write-Log "More information about error (if any) => $($error[0] | out-string)"
  }
}
