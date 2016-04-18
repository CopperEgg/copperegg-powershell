param([String]$UserAPIKey='')

$Servers = [System.Collections.ArrayList]@()

#Default globals
$MonitoringFrequency = 60
$MetricGroupName = "Azure_SQL"
$MetricGroupLabel = "Azure SQL Server Metrics"
$DashboardName = "Azure SQL Server"
$count = 1

$global_metricgroups = @( "MS_AzureSQL" )
$global_dashboards = @{
    "MS_AzureSQL" = @{ 'hash_name' = "MS_AzureSQL_Dash";  'dashboard_name' = 'D1' }
    "MS_MSSQL" = @{ 'hash_name' = "MSSQL_Dash";  'dashboard_name' = 'D2' }
    "AASS" =  @{ 'hash_name' = "MSSQL_Dash";  'dashboard_name' = 'D3' }
}

$global_metrics = @{
    "MS_AzureSQL" = @{ 'metric_hash' = "Azure_SQL";  'metric_label' = 'Azure label' }
    "MS_MSSQL" = @{ 'metric_hash' = "MS_MS_SQL";  'metric_label' = 'SQL Label' }
}

function ConfigureInstanceSpecificDetails {

    Write-Host "Azure Hostname:"
    $Hostname = Read-Host
    if ($Hostname -eq "")
    {
        Write-Host "Hostname cannot be blank. Stopping configuration for current instance."
        return
    }

    Write-Host "Host User:"
    $username = Read-Host
    if ($username -eq "")
    {
        Write-Host "Username cannot be blank. Stopping configuration for current instance."
        return
    }

    Write-Host "Azure Password:"
    $password = Read-Host

    $InstanceDetails = @{ "Hostname" = $Hostname ; "Username" = $username ;
                          "Password" = $password ; "Identifier" = "Server$count";
                        "metricgroups" = $global_metricgroups }

    Write-Host "Attempting to connect to instance with given settings...."
    #$Save = TestInstance($InstanceDetails)
    #if ($Save)
    #{
        # Write-Host "Connection successful"
        $script:Servers.Add($InstanceDetails)
        $script:count = [int]$count + 1
        Write-Host "Saving details for this instance ..."
        Write-Host $($script:Servers | Out-String)
    #}
}
function ConfigureAzureServerMonitoring {

  ##global_metricgroups will contain other service if required to moniter, so change there for asking service list
  $global_metricgroups = @( "MS_AzureSQL" )
  $metric_group = "MS_AzureSQL"
    Write-Host "Metric Group label ? [Default = Azure SQL Server Metrics"
    $script:MetricGroupLabel = Read-Host
    if ($script:MetricGroupLabel -eq "")
    {
        $script:MetricGroupLabel = "Azure SQL Server Metrics"
    }
    $global_metrics.$metric_group.metric_label =  $MetricGroupLabel
    Write-Host "Dashboard name ? [Default = Azure SQL Server]"
    $script:DashboardName = Read-Host
    if ($script:DashboardName -eq "")
    {
        $script:DashboardName = "Azure SQL Server"
    }
    $global_dashboards.$metric_group.dashboard_name = $DashboardName
    Write-Host "Completed general setup. Now configuring Instance specific details :"

    $ConfigureMoreInstances = $TRUE
    while ($ConfigureMoreInstances -eq 'Y')
    {
       ConfigureInstanceSpecificDetails
       Write-Host "Add more SQL instances ?[Default = No]"
       $ConfigureMoreInstances = Read-Host
       if ($ConfigureMoreInstances -eq 'Y')
       {
           Write-Host "Added One more instance"
       }
       else
       {
           $ConfigureMoreInstances = 'N'
       }
    }
}
function CreateConfig
{
$Initial = @'
copperegg:
  apikey: "REPLACE_API_KEY"
  requency: "REPLACE_FREQUENCY"
  local_remote: remote
  metricgroups:
LIST_OF_METRIC_GROUPS  dashboards:
LIST_OF_DASHBOARDS  servers:
LIST_OF_SERVERS
'@

foreach($server in $Servers) {
    $metricgroups = $global_metricgroups | foreach{"  - $_"} | Out-String
    $dashboards = $global_metricgroups  | foreach{$global_dashboards.$_} | foreach{ "  - $($_.hash_name)"} | Out-String
    $server = $Servers | foreach{"  - Server$($Servers.IndexOf($_) + 1)"} | Out-String
    $Initial -replace 'REPLACE_API_KEY', $UserAPIKey `
        -replace 'REPLACE_FREQUENCY', $MonitoringFrequency `
        -replace 'LIST_OF_METRIC_GROUPS', $metricgroups `
        -replace 'LIST_OF_DASHBOARDS', $dashboards `
        -replace 'LIST_OF_SERVERS', $server `
        | Out-File config.yml
}

$metric_template = @'
METRIC_HASH:
  group_name: 'METRIC_NAME'
  group_label: 'METRIC_LABEL'
  dashboard: METRIC_DASHBOARD_HASH
  mspaths:

'@

foreach($metric_group in $global_metricgroups) {
    $metric_template -replace 'METRIC_HASH', $metric_group `
    -replace 'METRIC_NAME', $global_metrics.$metric_group.metric_hash `
    -replace 'METRIC_LABEL', $global_metrics.$metric_group.metric_label `
    -replace 'METRIC_DASHBOARD_HASH', $global_dashboards.$metric_group.hash_name `
    | Out-File -append config.yml
}

$dashboard_template = @'
DASHBOARD_HASH:
  dash_name: 'USER_DASHBOARD_NAME'

'@

foreach($metric_group in $global_metricgroups) {
    $dashboard_template -replace 'DASHBOARD_HASH', $global_dashboards.$metric_group.hash_name `
    -replace 'USER_DASHBOARD_NAME', $global_dashboards.$metric_group.dashboard_name `
    | Out-File -append config.yml
}

$server_template = @'
ServerName:
  hostname: 'REPLACE_ME_WITH_HOSTNAME'
  username: 'REPLACE WITH MACHINE USERNAME'
  password: 'REPLACE WITH MACHINE USER PASSWORD'
  identifier: 'REPLACE WITH MACHINE IDENTIFIER'
  mssql_instancenames:
  - ServerName
  metricgroups:
  - MS_System_Memory
  - MS_Storage
  - MS_System
  - MS_NET_CLR
  - MS_ASP_NET
  - MS_Web_Services
  - MS_MSSQL
  - MS_AzureSQL
  - UserDefined

'@

$count = 1
foreach($server in $Servers) {
    $server_template -replace 'REPLACE_ME_WITH_HOSTNAME', $server.Hostname `
        -replace 'REPLACE WITH MACHINE USERNAME', $server.Username `
        -replace 'REPLACE WITH MACHINE USER PASSWORD', $server.Password `
        -replace 'REPLACE WITH MACHINE IDENTIFIER', $server.Identifier `
        -replace 'ServerName', "Server$count" `
        | Out-File -append config.yml
        $count++
}

}
function CreateDashboard
{
    Write-Host "Creating dashboard on Uptime Cloud Monitor interface ..."
    # RUN THE FOLLOWING ON DOWNLOADED PATH
    Initialize-Dashboards
}

function CreateMetricGroup
{
    Write-Host "Creating metricgrou on Uptime Cloud Monitor interface ..."
    # RUN THE FOLLOWING ON DOWNLOADED PATH
    Initialize-MetricGroups
}


###############################################################

ConfigureAzureServerMonitoring
CreateConfig

Import-Module .\CopperEgg.psd1
Initialize-MetricGroups
Initialize-Dashboards
Start-CopperEggMonitor
