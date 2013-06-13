import-module ..\PowerYaml\PowerYaml.psm1
import-module .\CopperEgg.psd1
Initialize-MetricGroups
Initialize-Dashboards
Start-CopperEggMonitor