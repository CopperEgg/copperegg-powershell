#
#	Initialize-Dashboards.ps1 contains code for creating a default set of dashboards.
# Copyright (c) 2012-2013 IDERA. All rights reserved.
#

function Initialize-Dashboards {

  foreach($id in $global:all_dashboardids){
    $dashdef = $global:cuconfig.$id
    if( $dashdef -eq $null) {
      Write-CuEggLog "Invalid config.yml: no definition for dashboard $id"
      Exit-Now
    }
    if( $id -eq 'MS_Memory_Dash' ) {
      # create System Memory dash
      if($global:dashes_tobuild -contains $id) {
        $dash_name = $dashdef.dash_name
        $metricgroup_id = 'MS_System_Memory'
        $required_mg = $global:cuconfig.$metricgroup_id.group_name
        $mg = Find-MetricGroup $required_mg
        if( $mg -ne $null ){
          $gname = $mg.name
          $dashcfg = $null
          $groupcfg = $mg.gcfg
          $warray = $groupcfg.metrics
          $widgets = @{
            "0" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "0", $warray[0].name);
                   };
            "1" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "1", $warray[1].name);
                   };
            "2" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "2", $warray[2].name);
                   };
            "3" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "3", $warray[3].name);
                   };
            "4" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "4", $warray[4].name);
                   };
            "5" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "5", $warray[5].name);
                   }
          }
          $order = @( "0","1","2","3","4","5" )
          $dashcfg = New-Object PSObject -Property @{
            "name" = $dash_name;
            "data" = @{"widgets" = $widgets; "order" = $order}
          }
          $result = New-Dashboard $dash_name $dashcfg
        }
      }
    } elseif( $id -eq 'MS_Storage_Dash' ) {
      # create Storage dash
      if($global:dashes_tobuild -contains $id) {
        $dash_name = $dashdef.dash_name
        $metricgroup_id = 'MS_Storage'
        $required_mg = $global:cuconfig.$metricgroup_id.group_name
        $mg = Find-MetricGroup $required_mg
        if( $mg -ne $null ){
          $gname = $mg.name
          $dashcfg = $null
          $groupcfg = $mg.gcfg
          $warray = $groupcfg.metrics
          $widgets = @{
            "0" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "0", $warray[0].name);
                   };
            "1" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "1", $warray[1].name);
                   };
            "2" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "2", $warray[2].name);
                   };
            "3" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "3", $warray[3].name);
                   };
            "4" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "4", $warray[4].name);
                   };
            "5" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "5", $warray[5].name);
                   };
            "6" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "6", $warray[6].name);
                   };
            "7" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "7", $warray[7].name);
                   };
            "8" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "8", $warray[8].name);
                   };
            "9" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "9", $warray[9].name);
                   };
            "10" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "10", $warray[10].name);
                   };
            "11" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "11", $warray[11].name);
                   };
            "12" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "12", $warray[12].name);
                   };
            "13" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "13", $warray[13].name);
                   };
            "14" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "14", $warray[14].name);
                   }
          }
          $order = @( "0","1","2","3","4","5","6","7","8","9","10","11","12","13","14" )

          $dashcfg = New-Object PSObject -Property @{
            "name" = $dash_name;
            "data" = @{"widgets" = $widgets; "order" = $order}
          }
          $result = New-Dashboard $dash_name $dashcfg
        }
      }
    } elseif( $id -eq 'MS_System_Dash' ) {
      # create System dash
      if($global:dashes_tobuild -contains $id) {
        $metricgroup_id = 'MS_System'
        $required_mg = $global:cuconfig.$metricgroup_id.group_name
        $dash_name = $dashdef.dash_name
        $mg = Find-MetricGroup $required_mg
        if( $mg -ne $null ){
          $gname = $mg.name
          $dashcfg = $null
          $groupcfg = $mg.gcfg
          $warray = $groupcfg.metrics
          $widgets = @{
            "0" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "0", $warray[0].name);
                   };
            "1" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "1", $warray[1].name);
                   };
            "2" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "2", $warray[2].name);
                   };
            "3" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "3", $warray[3].name);
                   };
            "4" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "4", $warray[4].name);
                   };
            "5" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "5", $warray[5].name);
                   };
            "6" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "6", $warray[6].name);
                   };
            "7" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "7", $warray[7].name);
                   };
            "8" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "8", $warray[8].name);
                   };
            "9" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "9", $warray[9].name);
                   };
            "10" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "10", $warray[10].name);
                   };
            "11" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "11", $warray[11].name);
                   }
          }
          $order = @( "0","1","2","3","4","5","6","7","8","9","10","11" )

          $dashcfg = New-Object PSObject -Property @{
            "name" = $dash_name;
            "data" = @{"widgets" = $widgets; "order" = $order}
          }
          $result = New-Dashboard $dash_name $dashcfg
        }
      }
    } elseif( $id -eq 'MS_NETCLR_Dash' ) {
      # create .NET CLR dash
      if($global:dashes_tobuild -contains $id) {
        $metricgroup_id = 'MS_NET_CLR'
        $required_mg = $global:cuconfig.$metricgroup_id.group_name
        $dash_name = $dashdef.dash_name
        $mg = Find-MetricGroup $required_mg
        if( $mg -ne $null ){
          $gname = $mg.name
          $dashcfg = $null
          $groupcfg = $mg.gcfg
          $warray = $groupcfg.metrics
          $widgets = @{
            "0" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "0", $warray[0].name);
                   };
            "1" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "1", $warray[1].name);
                   };
            "2" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "2", $warray[2].name);
                   };
            "3" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "3", $warray[3].name);
                   };
            "4" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "4", $warray[4].name);
                   }
          }
          $order = @( "0","1","2","3","4" )

          $dashcfg = New-Object PSObject -Property @{
            "name" = $dash_name;
            "data" = @{"widgets" = $widgets; "order" = $order}
          }
          $result = New-Dashboard $dash_name $dashcfg
        }
      }
    } elseif( $id -eq 'MS_ASPNET_Dash' ) {
      # create MS ASP.NET dash
      if($global:dashes_tobuild -contains $id) {
        $metricgroup_id = 'MS_ASP_NET'
        $required_mg = $global:cuconfig.$metricgroup_id.group_name
        $dash_name = $dashdef.dash_name
        $mg = Find-MetricGroup $required_mg
        if( $mg -ne $null ){
          $gname = $mg.name
          $dashcfg = $null
          $groupcfg = $mg.gcfg
          $warray = $groupcfg.metrics
          $widgets = @{
            "0" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "0", $warray[0].name);
                   };
            "1" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "1", $warray[1].name);
                   };
            "2" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "2", $warray[2].name);
                   };
            "3" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "3", $warray[3].name);
                   };
            "4" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "4", $warray[4].name);
                   };
            "5" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "5", $warray[5].name);
                   };
            "6" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "6", $warray[6].name);
                   };
            "7" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "7", $warray[7].name);
                   };
            "8" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "8", $warray[8].name);
                   };
            "9" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "9", $warray[9].name);
                   };
            "10" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "10", $warray[10].name);
                   }
          }
          $order = @( "0","1","2","3","4","5","6","7","8", "9", "10" )

          $dashcfg = New-Object PSObject -Property @{
            "name" = $dash_name;
            "data" = @{"widgets" = $widgets; "order" = $order}
          }
          $result = New-Dashboard $dash_name $dashcfg
        }
      }
    } elseif( $id -eq 'MS_Web_Dash' ) {
      # create Web Services dash
      if($global:dashes_tobuild -contains $id) {
        $metricgroup_id = 'MS_Web_Services'
        $required_mg = $global:cuconfig.$metricgroup_id.group_name
        $dash_name = $dashdef.dash_name
        $mg = Find-MetricGroup $required_mg
        if( $mg -ne $null ){
          $gname = $mg.name
          $dashcfg = $null
          $groupcfg = $mg.gcfg
          $warray = $groupcfg.metrics
          $widgets = @{
            "0" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "0", $warray[0].name);
                   };
            "1" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "1", $warray[1].name);
                   };
            "2" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "2", $warray[2].name);
                   };
            "3" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "3", $warray[3].name);
                   };
            "4" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "4", $warray[4].name);
                   };
            "5" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "5", $warray[5].name);
                   }
          }
          $order = @( "0","1","2","3","4","5" )

          $dashcfg = New-Object PSObject -Property @{
            "name" = $dash_name;
            "data" = @{"widgets" = $widgets; "order" = $order}
          }
          $result = New-Dashboard $dash_name $dashcfg
        }
      }
    } elseif( $id -eq 'MSSQL_Dash' ) {
      # create MSSQL dash
      if($global:dashes_tobuild -contains $id) {
        $metricgroup_id = 'MS_MSSQL'
        $required_mg = $global:cuconfig.$metricgroup_id.group_name
        $dash_name = $dashdef.dash_name
        $mg = Find-MetricGroup $required_mg
        if( $mg -ne $null ){
          $gname = $mg.name
          $dashcfg = $null
          $groupcfg = $mg.gcfg
          $warray = $groupcfg.metrics
          $widgets = @{
            "0" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "0", $warray[0].name);
                   };
            "1" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "1", $warray[1].name);
                   };
            "2" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "2", $warray[2].name);
                   };
            "3" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "3", $warray[3].name);
                   };
            "4" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "4", $warray[4].name);
                   };
            "5" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "5", $warray[5].name);
                   };
            "6" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "6", $warray[6].name);
                   };
            "7" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "7", $warray[7].name);
                   };
            "8" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "8", $warray[8].name);
                   }
          }
          $order = @( "0","1","2","3","4","5","6","7","8" )

          $dashcfg = New-Object PSObject -Property @{
            "name" = $dash_name;
            "data" = @{"widgets" = $widgets; "order" = $order}
          }
          $result = New-Dashboard $dash_name $dashcfg
        }
      }
    } else {
      #id -eq 'My_Metrics_Dash'
      # This is an example dashboard for UserDefined metrics.
      if($global:dashes_tobuild -contains $id) {
        $metricgroup_id = 'User_Defined'
        $required_mg = $global:cuconfig.$metricgroup_id.group_name
        $dash_name = $dashdef.dash_name
        $mg = Find-MetricGroup $required_mg
        if( $mg -ne $null ){
          $gname = $mg.name
          $dashcfg = $null
          $groupcfg = $mg.gcfg
          $warray = $groupcfg.metrics
          $widgets = @{
            "0" = @{
                  "type"="timeline";
                  "style"="values";
                  "match"="all";
                  "metric" = @($gname, "0", $warray[0].name);
                   }
          }
          $order = @( "0" )

          $dashcfg = New-Object PSObject -Property @{
            "name" = $dash_name;
            "data" = @{"widgets" = $widgets; "order" = $order}
          }
          $result = New-Dashboard $dash_name $dashcfg
        }
      }
    }
  }
}
