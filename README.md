CoppereggPowershell
=============

The Uptime Cloud Monitor Powershell module is a Powershell interface to the Uptime Cloud Monitor API, making it simple to create custom metrics and dashboards for Microsoft Windows systems.

##Synopsis
The module includes:
  - CopperEgg.psm1... contains Powershell functions that are wrappers for the Uptime Cloud Monitor API
  - Initialize-MetricGroups ... creates metric groups, and sends them to Uptime Cloud Monitor
  - Initialize-Dashboards ... creates custom dashboards, and sends them to Uptime Cloud Monitor
  - Start-CopperEggMonitor ... starts one or more background jobs that periodically transmit your metrics to Uptime Cloud Monitor
  - Start-DebugMonitor ... performs the same functionality as Start-CopperEggMonitor, but in the foreground, and with debug output.
  - and other utilities.

This module provides a 'Works-Out-of-the-Box' set of default metrics and dashboards for
  - MSSQL
  - .NET CLR
  - ASP.NET
  - IIS
  - and a variety of system-level Microsoft performance counters.

This module will replace revealmetrics-powershell, which will be deprecated. CopperEgg-Powershell is configured with a yaml configuration
file, and supports both local and remote monitoring.

As of 1.0.0, errors and events are logged. Look for logs here: Modules/CopperEgg/Logs

## Requirements
This release requires Powershell v3.0, which ships with Windows 8 and Windows Server 2012.
It has also been tested on Windows Server 2008r2 and Windows 7, with Powershell v3.0 installed.

You can download Powershell v3.0 here:
* [Microsoft Powershell v3.0](http://www.microsoft.com/en-us/download/details.aspx?id=34595)

A Uptime Cloud Monitor account is also required. If you don't have one yet, check it out:
* [IDERA](http://idera.com)

You will also need to install PowerYaml, which is used to parse the config.yml file.
The procedure will be detailed below.


## Installation

* Start Windows Powershell, running as Administrator

* Set the ExecutionPolicy to Unrestricted or RemoteSigned:

```ruby
Set-ExecutionPolicy Unrestricted
```
* Create installation directories for PowerYaml and Uptime Cloud Monitor.

The following instructions assume that you will install PowerYaml in this directory:

```ruby
"c:\Program Files (x86)\CopperEgg\Modules\PowerYaml"
```

... and copperegg-powershell in this directory:

```ruby
"c:\Program Files (x86)\CopperEgg\Modules\CopperEgg"
```

```ruby
New-Item 'c:\Program Files (x86)\CopperEgg\Modules\CopperEgg' -type directory
New-Item 'c:\Program Files (x86)\CopperEgg\Modules\PowerYaml' -type directory
cd 'c:\Program Files (x86)\CopperEgg\Modules\CopperEgg'
```
* Create a Powershell profile. If you have already set up a Powershell profile, you can skip to 'Edit your powershell profile'

There are a number of different profiles used by Powershell and PowershellISE, and they are in different places. :(
To see the choices, enter the following:

```ruby
$PROFILE | Format-List * -Force
```
The following instructions assume that you will create and edit the AllUsersAllHosts profile:

```ruby
new-item $PROFILE.AllUsersAllHosts -ItemType file -Force
```
* Edit your powershell profile to include a path to the Uptime Cloud Monitor and PowerYaml module directories.
Add the following lines to your powershell profile:

```ruby
Set-Location "c:\Program Files (x86)\CopperEgg\Modules\CopperEgg"
$env:PSModulePath = $env:PSModulePath +  ";c:\Program Files (x86)\CopperEgg\Modules\CopperEgg" + ";c:\Program Files (x86)\CopperEgg\Modules\PowerYaml"
import-module ..\PowerYaml\PowerYaml.psm1
```

* Clone the following repositories:

```ruby
git clone https://github.com/CopperEgg/copperegg-powershell.git

git clone https://github.com/scottmuc/PowerYaml.git
```

* Copy the contents of the newly-cloned copperegg-powershell directory to "c:\Program Files (x86)\CopperEgg\Modules\CopperEgg".

* Copy the contents of the newly-cloned poweryaml directory to "c:\Program Files (x86)\CopperEgg\Modules\PowerYaml".

* If the archive flags are set on any of the files in either of these two directories, clear them.

* At this point, you will need to create your config.yml file. Copy the config-sample.yml file to config.yml.

### Edit the config.yml file :

* enter your Uptime Cloud Monitor APIKEY in the the apikey field,

* set the frequency (actually the sampling period ... a value of 60 means obtain a sample every 60 seconds.)

* set the 'local_remote' flag as desired; local means the machine running copperegg-powershell will only monitor
those metricgroups called out in the server definition with hostname equal to that of the local host. remote means the
machine running copperegg-powershell will only monitor metricgroups called out in the server definitions with hostnames
NOT equal to that of the local host. Finally, if set to all, the machine running copperegg-powershell will monitor
metricgroups in server definitions of both local and remote machines.

* replace 'Server1' with your server name. This name field allows you to name your servers as you like; the associated
Server definition must contain the Windows machine name. (see below)

* Update the Server Definition (in config-sample.yml, the block at the end of the file beginning with Server1:)
Each Server Definition block must have a valid hostname, and a metricgroups section, listing which of the metric groups defined
earlier in the file to monitor. If this instance will monitor MSSQL (locally or remotely), you must also add a
a mssql_instancenames: section, and list one (or more) instances to monitor.

Save the file, and close it.

## Usage

####Load the Uptime Cloud Monitor module:

```ruby
import-module .\CopperEgg.psd1
```
####Initialize the default metric groups and dashboards:
```ruby
Initialize-MetricGroups
Initialize-Dashboards
```
####Start monitoring:

```ruby
Start-CopperEggMonitor
```
The module will set up a number of background jobs. You can continue to use your powershell UI, and the monitoring will continue.
Now go have a look at your Uptime Cloud Monitor UI, and you will see your new dashboards up and running!

####To stop monitoring:
```ruby
Stop-CopperEggMonitor
```

####To remove all loaded Uptime Cloud Monitor modules:
```ruby
Remove-AllCopperEgg
```

###To Run Your CopperEgg-StartMonitor.ps1 script 'as a service'

Specifically, these instructions are for ensuring that your monitoring powershell scripts resume running after restart or power-cycle. At this point, we do not support running the Powershell scripts as a Windows Service ... but using the Windows Task Scheduler, you can do very close to the same thing.

* As Administrator, enter the Task Scheduler (Control Panel-> Administrative Tools->Task Scheduler)

* Create Task General
  - Name CopperEggTask
  - When running the task, use the Administrator account.
  - Run whether user is logged in or not
  - Run with Highest Privileges
  - Configure for the OS you are using

* Create Task Trigger
  - Begin the Task On a Schedule
  - Daily
  - set time to current time
  - Recur every 1 day
  Advanced Settings:
  - Repeat task every 5 minutes, for duration Indefinitely
  Check the Enabled box. Other boxes cleared.

* Create Task Actions
  - Start a Program
  Program     C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
  Arguments   -noexit -File "C:\Program Files (x86)\CopperEgg\Modules\CopperEgg\CopperEggTask.ps1"
  Options field blank

  NOTE: You can select the 32 or 64 bit powershell executable. Above the 64 bit is specified.

* Create Task Conditions
  - Leave all boxes cleared

* Create Task Settings
  - Check Allow Task to be run on demand, Run task as soon as possible after scheduled start is missed, and if the task fails, restart every 1 minute
  - Attempt to restart up to 3 times.
  - Leave the remaining boxes un-checked.
  - If the task is already running, then the following rule applies:
    Do not start a new instance.

Close the Task Scheduler. CopperEggTask.ps1 should start (if not already started) within 5 minutes.


## Questions / Problems?

You can find detailed documentation of the Uptime Cloud Monitor API here:
* [Uptime Cloud Monitor API](http://dev.copperegg.com/)

##  LICENSE

(The MIT License)

Copyright © 2012 [IDERA](http://idera.com)

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without
limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons
to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
