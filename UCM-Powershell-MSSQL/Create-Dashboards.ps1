$root = $PSScriptRoot

. $root\Utils.ps1

<# Custom method to Create a dashboard based on parameters passed to the script.
   Arguments : ApiServer (Address of API Server, kept flexible for testing on dev/staging env)
               Apikey (Apikey of user using which metric group is created and samples are sent)
               DashboardName (Name of the dashboard)
#>
function Create-Dashboard([string]$ApiServer, [string]$ApiKey, [string]$ServiceName, [string]$DashboardName)
{

  $URI = "$ApiServer/v2/revealmetrics/dashboards"
  $AuthInfo = $ApiKey + ':U'
  $AuthObject = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($AuthInfo))

  $Request = New-Object System.Net.WebClient
  $Request.Headers.Add('Authorization', $AuthObject)
  $Request.Headers.Add('Accept', 'application/json')
  $Request.Headers.Add("User-Agent", "PowerShell")
  $Request.Headers.Add('Content-Type', 'application/json')
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
  [System.Net.ServicePointManager]::Expect100Continue = $false
  try
  {
    $Result = $Request.DownloadString($URI)
    $DataJson = $Result | ConvertFrom-Json
    if($DataJson.name -contains $DashboardName){
      Write-Log "Dashboard with same name already exists"
      return
    }
  }
  Catch [system.exception]
  {
    Write-Log "Exception in sending request for getting dashbords on Uptime Cloud Monitor"
    Write-Log "Exception name => $($_.Exception.GetType().Name) - $($_.Exception.Message), at line number $($_.InvocationInfo.ScriptLineNumber)"
    Write-Log "More information about error (if any) => $($error[0] | out-string)"
    return
  }

  $Request = New-Object System.Net.WebClient
  $Request.Headers.Add('Authorization', $AuthObject)
  $Request.Headers.Add('Accept', '*/*')
  $Request.Headers.Add("User-Agent", "PowerShell")
  $Request.Headers.Add('Content-Type', 'application/json')
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
  [System.Net.ServicePointManager]::Expect100Continue = $false

  # Get the json, make a hashtable out of it, modify the requried parameters and convert back to JSON
  $DataJson = Get-Content -Raw -Path "$PSScriptRoot\dashboard.json" | ConvertFrom-JSON
  $ConvertedJson = $DataJson.$ServiceName
  $ConvertedJson.name = $DashboardName
  $DataJson = $ConvertedJson | ConvertTo-JSON -Depth 10

  Write-Log "Updated DataJson parameters from config : $DataJson"
  Try
  {
    $Result = $Request.UploadString($URI, $DataJson)
    $StatusCode = $($Request.ResponseHeaders.Item('status'))
    Write-Log "Succesfully created dashboard on Uptime Cloud Monitor [$StatusCode]"
    if($StatusCode -ne "200 OK")
    {
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
