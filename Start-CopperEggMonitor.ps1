#
# Start-CopperEggMonitor.ps1 kicks off a series of background monitoring jobs.
#
# Copyright (c) 2012,2013 CopperEgg Corporation. All rights reserved.
#
$global:CopperEggJobs = @()
$global:CopperEggJobCount = 0
function Start-CopperEggMonitor {
  $cmd = 'c:\Program Files (x86)\CopperEgg\Modules\CopperEgg\Start-CopperEggJob.ps1'
  $cmdCustom = 'c:\Program Files (x86)\CopperEgg\Modules\CopperEgg\Start-CustomCopperEggJob.ps1'
  $mhj = $global:master_hash | ConvertTo-Json -Depth 5

  foreach( $id in $global:all_metricgroupids ) {
    # All metric groups beginning with "MS_" can be handled the same way ... with the exception of
    # MS_MSSQL.
    if( $id.StartsWith('MS_') -eq 'True' ) {
      if( $id -eq 'MS_MSSQL') {
        # Handle MSSQL monitoring
        $required_mg = $global:cuconfig.$id.group_name
        $mg = Find-MetricGroup $required_mg
        if( $mg -ne $null ){
          [string[]]$hosts = $mg.hosts
          if($hosts.length -gt 0){
            $gname = $mg.name
            [string[]]$cpath = $mg.mspaths
            $groupcfg = $mg.gcfg
            $freq = $groupcfg.frequency
            Write-CuEggLog "Starting Monitor of $gn at an interval of $freq seconds; Hosts to monitor:"
            foreach($h in $hosts) {
              $h
            }
            $j = Start-Job -ScriptBlock {param($cmd,$cpath,$gname,$mhj,$global:apikey,$hosts,$global:mypath,$mg) & $cmd $cpath $gname $mhj $global:apikey $hosts $global:mypath $mg} -ArgumentList @($cmd,$cpath,$gname,$mhj,$global:apikey,$hosts,$global:mypath,$mg)
            $global:CopperEggJobs = $global:CopperEggJobs + $j
            $global:CopperEggJobCount++
          }
        }
      } else {
        # Handle all other metric groups starting with MS_
        # 'MS_System_Memory', 'MS_Storage', 'MS_System', 'MS_NET_CLR'
        # 'MS_ASP_NET', 'MS_Web_Services'
        $required_mg = $global:cuconfig.$id.group_name
        $mg = Find-MetricGroup $required_mg
        if( $mg -ne $null ){
          [string[]]$hosts = $mg.hosts
          if($hosts.length -gt 0){
            $gname = $mg.name
            [string[]]$cpath = $mg.mspaths
            $groupcfg = $mg.gcfg
            $freq = $groupcfg.frequency
            Write-CuEggLog "Starting Monitor of $gn at an interval of $freq seconds; Hosts to monitor:"
            foreach($h in $hosts) {
              $h
            }
            $j = Start-Job -ScriptBlock {param($cmd,$cpath,$gname,$mhj,$global:apikey,$hosts,$global:mypath,$mg) & $cmd $cpath $gname $mhj $global:apikey $hosts $global:mypath $mg} -ArgumentList @($cmd,$cpath,$gname,$mhj,$global:apikey,$hosts,$global:mypath,$mg)
            $global:CopperEggJobs = $global:CopperEggJobs + $j
            $global:CopperEggJobCount++
          }
        }
      }
    } else {
      # handle the user-defined metric groups
      $id = 'UserDefined'
      $required_mg = $global:cuconfig.$id.group_name
      $mg = Find-MetricGroup $required_mg
      $mg = $null
      if( $mg -ne $null ){
        $gname = $mg.name
        $groupcfg = $mg.gcfg
        $freq = 600
        [string[]]$cpath = $mg.CE_Variables
        [string]$host = $global:computer
        Write-CuEggLog "Starting Custom job, monitoring $gname at an interval of $freq seconds"
        $j = Start-Job -ScriptBlock {param($cmdCustom,$cpath,$gname,$mhj,$global:apikey,$host,$global:mypath,$mg) & $cmdCustom $cpath $gname $mhj $global:apikey $host $global:mypath $mg} -ArgumentList @($cmdCustom,$cpath,$gname,$mhj,$global:apikey,$host,$global:mypath,$mg)
        $global:CopperEggJobs = $global:CopperEggJobs + $j
        $global:CopperEggJobCount++
      }
    }
  }
  Write-CuEggLog "Current Running Jobs : $global:CopperEggJobCount"
  $global:CopperEggJobs
}
