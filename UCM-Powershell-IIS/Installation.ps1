
param (
    [string]$server = "http://defaultserver",
    [Parameter(Mandatory=$true)][string]$UserApiKey,
    [Parameter(Mandatory=$true)][string]$ApiHost
 )

$service = 'Web_Service'
$InstanceNumber='1'
$ConfigDirectory = "$env:programfiles\UCM-Powershell\IIS"
$XmlfilePath = "$ConfigDirectory\config.xml"
$MetricGroup = @{
  'MetricGroupName' = "IIS";
  'MetricGroupLabel' = "Web Server Metrics";
  'DashboardName' = "MicroSoft Web Server";
  'Frequency' = 60;
  'Servers' = [System.Collections.ArrayList]@()
}

# Stores list of services(metric groups) to be monitored for which dashboards are created
$SelectedServices = [System.Collections.ArrayList]@()

# Hint texts for user, for the sake of verbosity
$SampleRateHintText        = "Hint : Monitoring Frequency of 15 seconds means that a sample is sent to us after 15 seconds."
$MetricGroupNameHintText   = "Hint : This is the name which appears in 'Custom Tab -> Metric Groups -> Name field' in Uptime Cloud Monitor UI."
$MetricGroupLabelHintText  = "Hint : This is the label which appears in 'Custom Tab -> Metric Groups -> Label field' in Uptime Cloud Monitor UI."
$DashboardNameHintText     = "Hint : This is the name of dashboard which appears in 'Dashboards' tab and will show all your Monitored Instances at one place."
$UniqueNameHintText        = "Hint : Unique name represents this particular instance and is visible at Custom -> Custom Objects -> Identifier."
$HostNameHintText          = "Hint : Hostname is the 'computer name' of the server instance where the Web Service is running.`
For a local instance, you can leave this as blank in case this is first system you have configured for monitoring.`
If you have multiple servers with same 'computer name' then keep this field as blank if IIS is running on current system else, mention any random name here"
$HostAddressHintText       = "Hint : This is usually the 'Servername' in your connection string (server IP/hostname/public DNS)."
$UserNameHintText          = "Hint : Username (with domain, if any) for user which have access to Powershell Monitoring Group on the remote system."
$PassWordHintText          = "Hint : Password for the above mentioned user."


$LogFile = "$PSScriptRoot\ucm-metrics.log"
function Write-Log($Message)
{
  $TimeStamp =  Get-Date -Format "yyyy-MM-dd hh:mm:ss"
  $ProcessId = $([System.Diagnostics.Process]::GetCurrentProcess().Id)
  Add-Content $LogFile -value "$TimeStamp MSIIS-Powershell-Agent pid:$ProcessId> $Message"
}

function MakeStartupService
{
  Try
  {
    Write-Host "Creating Startup job"

    $jobName = "UCM_IIS"
    $job = Get-ScheduledJob -Name $jobName -ErrorAction SilentlyContinue

    if ($job -ne $null)
    {
      Write-Host "Un-registering existing job"
      Unregister-ScheduledJob -Name $jobName -Confirm:$false
    }

    $filePath = "$ConfigDirectory\Start-Ucm-Monitor.ps1"
    $jobTrigger = New-JobTrigger -AtStartup -RandomDelay 00:00:30
    $jobSchedule = New-ScheduledJobOption -RunElevated -WakeToRun
    Write-Host "Enter credentials for Admin account which is added to local policy 'Logon as batch user'"
    Start-Sleep -Seconds 2
    $cred = Get-Credential -UserName MyDomain\MyAccount -Message "Scheduled job credentials for admin user."
    if ($cred) {
      $user = $cred.username
      $pass = $cred.GetNetworkCredential().password
    }
    else
    {
      Write-Host "Credentials are not valid for scheduled job user mentioned!"
      Throw "No valid credentials for scheduled job user mentioned!"
    }

    $sb = {
      param([string]$path)
      PowerShell -NoLogo -NonInteractive -File $path
    }

    Register-ScheduledJob -Name $jobName -ScriptBlock $sb -ArgumentList ("$filePath") -Credential $cred -ScheduledJobOption $jobSchedule -Trigger $jobTrigger
    $job = Get-ScheduledJob -Name $jobName -ErrorAction SilentlyContinue
    if ($job -ne $null)
    {
      Write-Output "Created scheduled job: '$($job.ToString())'."
    }
    else
    {
      Write-Output "Failed creating scheduled job"
    }
  }
  Catch [system.exception]
  {
    Write-Host "Failed creating scheduled job"
  }
}

function CreateDashboard
{
   . "$ConfigDirectory\Create-Dashboards.ps1"
   $DashboardName = $MetricGroup.DashboardName
   $MetricGroupName = $MetricGroup.MetricGroupName

   cat "$ConfigDirectory\dashboard.json" | % { $_ -replace "metric_group_name",$MetricGroupName } > "$ConfigDirectory\temp.json"
   cat "$ConfigDirectory\temp.json" | % { $_ -replace "dashboard_name",$DashboardName } > "$ConfigDirectory\temp2.json"
   Remove-Item "$ConfigDirectory\dashboard.json" -ErrorAction SilentlyContinue
   Remove-Item "$ConfigDirectory\temp.json" -ErrorAction SilentlyContinue
   Rename-Item "$ConfigDirectory\temp2.json" "$ConfigDirectory\dashboard.json"
   Write-Host "Creating dashboard '$DashboardName' on Uptime Cloud Monitor interface for MS Web Server"
   Create-Dashboard $ApiHost $UserAPIKey $service $DashboardName
}

function GetUserCreds ($InstanceDetails)
{
  $username = [string]$InstanceDetails.Username.trim()
  $password = [string]$InstanceDetails.Password.trim()
  $password = $password|ConvertTo-SecureString -AsPlainText -Force
  $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
  return $creds
}

function TestIfLocalSystem ($serverName)
{
  return ($env:computername -eq $serverName)
}

function CreateXML
{
  Try
  {
    Write-Host "Saving settings"
    $XMLWriter = New-Object System.XMl.XmlTextWriter($XmlfilePath, $Null)

    $XMLWriter.Formatting = "Indented"
    $XMLWriter.Indentation = "4"

    $XMLWriter.WriteStartDocument()

    $XMLWriter.WriteStartElement("Settings")

    $XMLWriter.WriteStartElement("UptimeCloudMonitor")
    $XMLWriter.WriteElementString("Apikey",$script:UserAPIKey)
    $XMLWriter.WriteElementString("ApiServer",$script:ApiHost)
    $XMLWriter.WriteEndElement()

    $XMLWriter.WriteStartElement("MetricGroups")

    $server_count = $MetricGroup.Servers.Count
    if($server_count -gt 0)
    {
      $XMLWriter.WriteStartElement("MetricGroup$Count")
      $XMLWriter.WriteElementString("ServiceName", $service)
      $XMLWriter.WriteElementString("DashboardName", "$($MetricGroup.DashboardName)")
      $XMLWriter.WriteElementString("MetricGroupName", "$($MetricGroup.MetricGroupName)")
      $XMLWriter.WriteElementString("MetricGroupLabel", "$($MetricGroup.MetricGroupLabel)")
      $XMLWriter.WriteElementString("Frequency", "$($MetricGroup.Frequency)")

      $XMLWriter.WriteStartElement("Servers")
      $Index = 1

      ForEach ($Server in $MetricGroup.Servers)
      {
        $XMLWriter.WriteStartElement("Server$Index")
        $XMLWriter.WriteElementString("SystemIdentifier",$Server.UniqueName)
        $XMLWriter.WriteElementString("Hostname",$Server.Hostname)
        $XMLWriter.WriteElementString("HostAddress",$Server.HostAddress)
        $XMLWriter.WriteElementString("Username",$Server.Username)
        $XMLWriter.WriteElementString("Password",$Server.Password)
        $XMLWriter.WriteStartElement("Sites")

        if ( TestIfLocalSystem $Server.Hostname )
        {
          $Sites = Get-Website
        }
        else
        {
          $cred = GetUserCreds($Server)
          $Sites = Invoke-Command -ComputerName $Server.HostAddress -credential $cred { Import-Module WebAdministration;
                   Get-Website}
        }

        $SiteList = [System.Collections.ArrayList]@()
        foreach($Site in $Sites) {
          $Counter = $SiteList.Add($Site.name) + 1
          $XMLWriter.WriteStartElement("Site$Counter")
          $name = $Site.name
          $bindings = $Site.bindings.collection.bindinginformation.split(":")
          $ip = $bindings[0]
          $port = $bindings[1]
          $XMLWriter.WriteElementString("SiteName",$name)
          $XMLWriter.WriteElementString("IpAddress", $ip)
          $XMLWriter.WriteElementString("Port", $port)
          $XMLWriter.WriteEndElement()
        }
        Write-Host "Adding monitoring for these sites under IIS server ($($Server.Hostname)): $($SiteList -join ', ')"
        Write-Host "To Add/Delete the monitoring for any specific site you can edit the config.yml generated."
        Write-Host "Configuration file can be found here $env:programfiles\UCM-Powershell\IIS\config.xml"
        # Closing Sites Element
        $XMLWriter.WriteEndElement()
        # Closing particular server, say Server1
        $XMLWriter.WriteEndElement()
        $Index++
      }
      # Close Servers tag
      $XMLWriter.WriteEndElement()

      # Close a particular MetricGroup tag, say MetricGroup1 tag
      $XMLWriter.WriteEndElement()
      $Count++
    }
    # Close MetricGroup
    $XMLWriter.WriteEndElement()

    # Close Settings
    $XMLWriter.WriteEndElement()

    # End the XML Document
    $XMLWriter.WriteEndDocument()

    # Finish The Document
    $XMLWriter.Flush()
    $XMLWriter.Close()
  }
  Catch [system.exception]
  {
    Write-Host "Error creating config file. Check connectivity to the host/permissions for running this script."
    Write-Host "Exception name => $($_.Exception.GetType().Name) - $($_.Exception.Message), at line number $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "More information about error (if any) => $($error[0] | out-string)"
    exit
  }
}

function SaveIncorrectHost ($Reason)
{
  Write-Host
  if ($Reason -eq 'ServerUnreachable')
  {
    # If we are not able to connect then, the Hostname mentioned is incorrect/unreachable
    Write-Host -ForegroundColor YELLOW "Not able to connect to the server. Please check server details/your firewall settings."
    Write-Host -ForegroundColor YELLOW "Also, check WinRM settings on system."
  }
  elseif ($Reason -eq 'PermissionIssue')
  {
    Write-Host -ForegroundColor YELLOW "Not able to fetch stats for the system specified."
    Write-Host -ForegroundColor YELLOW "Probably issue with user credentials/trusted WINRM machines/firewall settings."
  }
  Write-Host
  Write-Host "Are you sure you want to save these settings ? [Y/N] [Default=No]"
  $Save = Read-Host
  if ($Save -eq "Y")
  {
    return $TRUE
  }
  else
  {
    return $FALSE
  }
}

function TestConnection ($InstanceDetails)
{
  Try
  {
    $ServerType = 'remote'
    $Server = ''
    if ( TestIfLocalSystem $InstanceDetails.Hostname )
    {
      $ServerType = 'local'
      $Server = $InstanceDetails.Hostname
    }
    else
    {
      $Server = $InstanceDetails.HostAddress
    }
    # Try to connect to the server specified
    $result = Test-WSMan -ComputerName $Server
  }
  Catch [system.exception]
  {
    return SaveIncorrectHost('ServerUnreachable')
  }

  Try
  {
    if($result)
    {
      # If the script reaches here it means connection is successful. Now let's check if we can access stats
      if ( $SeverType -eq 'remote')
      {
        $cred = GetUserCreds($InstanceDetails)
        $result = Invoke-Command  -ComputerName $Server -credential $cred { Import-Module WebAdministration;
                  Get-Counter -listset * }
      }
      else
      {
        $result = Get-Counter -listset *
      }
      if ([string]::IsNullOrEmpty($result))
      {
        return SaveIncorrectHost('PermissionIssue')
      }
      else
      {
        return $TRUE
      }
    }
    else
    {
      return SaveIncorrectHost('ServerUnreachable')
    }
  }
  Catch [system.exception]
  {
    return SaveIncorrectHost('PermissionIssue')
  }
}

function ConfigureInstanceSpecificDetails($InstanceNumber, $DefaultHostName, $DefaultHostAddress)
{
  Write-Host "Unique name for this instance ? [Default = Instance$InstanceNumber]"
  PrintHintText $script:UniqueNameHintText
  $UniqueName = Read-Host
  if ($UniqueName -eq "")
  {
    $UniqueName = "Instance$InstanceNumber"
  }

  Write-Host "Servername ? [Default = $DefaultHostName]"
  PrintHintText $script:HostNameHintText
  $InstanceName = Read-Host
  if ($InstanceName -eq "")
  {
    $InstanceName = "$DefaultHostName"
  }

  Write-Host "Server Address ? [Default = $DefaultHostAddress]"
  PrintHintText $script:HostAddressHintText
  $InstanceAddress = Read-Host
  if ($InstanceAddress -eq "")
  {
    $InstanceAddress = "$DefaultHostAddress"
  }

  if ( TestIfLocalSystem $InstanceName )
  {
     $UserName = ""
     $Password = ""
  }
  else
  {
    Write-Host
    Write-Host "Add credentials for user on remote system with access to Powershell Monitoring Group"
    Write-Host "Username ?"
    PrintHintText $script:UserNameHintText
    $UserName = Read-Host

    Write-Host "Password ?"
    PrintHintText $script:PassWordHintText
    $Password = Read-Host
  }

  $InstanceDetails = @{ "Hostname" = "$InstanceName" ;
    "HostAddress" = "$InstanceAddress";
    "Username" = "$UserName" ;
    "Password" = "$Password" ;
    "UniqueName" = "$UniqueName" ;
  }

  Write-Host "Attempting to connect to instance with given settings...."
  $Save = TestConnection($InstanceDetails)
  if ($Save)
  {
    # $Index is not used anywhere but if we don't store the result of .Add method somewhere,
    # it will be echoed to the powershell console and we don't want that.
    Write-Host "Connection successful"
    $Index = $script:MetricGroup.Servers.Add($InstanceDetails)
    Write-Host "Instance details saved."
    Write-Host
  }
}

function ConfigureDetails()
{
  $Frequencies = 15, 60, 300, 900, 3600

  Write-Host "Please specify the Monitoring Frequency [sample rate]. It can be one of [15, 60, 300, 900, 3600] seconds [Default = 60]"
  $MonitoringFrequency = Read-Host
  $MonitoringFrequency = $Frequencies -eq $MonitoringFrequency
  if (!$MonitoringFrequency)
  {
    $MonitoringFrequency = 60
  }
  $script:MetricGroup.Frequency = $MonitoringFrequency

  Write-Host "Metric group name ? [Default = $($MetricGroup.MetricGroupName)]"
  PrintHintText $script:MetricGroupNameHintText
  $name = Read-Host
  if ($name -eq "")
  {
    $name = "IIS"
  }
  $script:MetricGroup.MetricGroupName = $name

  Write-Host "Metric group label ? [Default = $($MetricGroup.MetricGroupLabel)]"
  PrintHintText $script:MetricGroupLabelHintText
  $label = Read-Host
  if ($label -eq "")
  {
    $label = $MetricGroup.MetricGroupLabel
  }
  $script:MetricGroup.MetricGroupLabel = $label

  Write-Host "Dashboard name ? [Default = $($MetricGroup.DashboardName)]"
  PrintHintText $script:DashboardNameHintText
  $dashboard_name = Read-Host
  if ($dashboard_name -eq "")
  {
    $dashboard_name = $MetricGroup.DashboardName
  }
  $script:MetricGroup.DashboardName = $dashboard_name
  Write-Host "Completed general setup. Now configuring Instance specific details :"
  Write-Host

  $ConfigureMoreInstances = $TRUE
  $InstanceNumber = 1

  while ($ConfigureMoreInstances)
  {
    if ($InstanceNumber -eq 1)
    {
      ConfigureInstanceSpecificDetails "$InstanceNumber" "$env:computername" "localhost"
    }
    else
    {
      ConfigureInstanceSpecificDetails "$InstanceNumber" "MyComputer" "local"
    }
    Write-Host "Add more instances ? [Y/N] [Default = No]"
    $ConfigureMoreInstances = Read-Host
    if ($ConfigureMoreInstances -eq 'Y')
    {
      $InstanceNumber++
    }
    else
    {
      $ConfigureMoreInstances = $FALSE
    }
  }

}

function PostInstallationMessage()
{
  Write-Host
  Write-Host "Completed installation and configuration for UCM-Powershell. Starting Job"
  Write-Host

  powershell -file "$ConfigDirectory\Start-Ucm-Monitor.ps1" --noninteractive

  Write-Host "Installation details   - "
  Write-Host
  Write-Host "Installation directory : $env:programfiles\UCM-Powershell\IIS"
  Write-Host "Start job              : $env:programfiles\UCM-Powershell\IIS\Start-UCM-Monitor.ps1"
  Write-Host "Stop job               : $env:programfiles\UCM-Powershell\IIS\Stop-UCM-Monitor.ps1"
  Write-Host "Configuration file     : $env:programfiles\UCM-Powershell\IIS\config.xml"
  Write-Host "Logfile path           : $env:programfiles\UCM-Powershell\IIS\ucm-metrics.log"
  Write-Host
  Write-Host "In case you want to start/stop the job manually, you can open the respective start/stop job files with powershell."
  Write-Host "Thank you for installing Uptime Cloud Monitor Metric Agent. Please press a key to exit..."
  Read-Host
}

function PrintHintText ($Message)
{
  Write-Host -ForegroundColor GREEN $Message
}

ConfigureDetails
CreateXML
CreateDashboard

MakeStartupService
PostInstallationMessage
