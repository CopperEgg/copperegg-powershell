<# This file simply creates a file inside temp directory. The 'UCM-SQL-Monitor.ps1' job keeps
   checking for this file. If this file exists, the script kills itself (and child jobs), hence
   stopping the metrics monitoring utility.
#>

New-Item -Type File -Path "$env:temp\stop-ucm-monitor.txt"
