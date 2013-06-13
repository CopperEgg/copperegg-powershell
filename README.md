revealmetrics-powershell
=============

The CopperEgg Powershell module is a Powershell interface to the CopperEgg API, making it simple to create custom metrics and dashboards for Microsoft Windows systems.

##Synopsis
The module includes:
  - CopperEgg.psm1... contains Powershell functions that are wrappers for the CopperEgg API
  - Initialize-MetricGroups ... creates metric groups, and sends them to CopperEgg
  - Initialize-Dashboards ... creates custom dashboards, and sends them to CopperEgg
  - Start-CopperEggMonitor ... starts one or more background jobs that periodicaly transmit your metrics to CopperEgg
  - and other utilities.

This module provides a 'Works-Out-of-the-Box' set of default metrics and dashboards for
  - MSSQL
  - .NET CLR
  - ASP.NET
  - IIS
  - and a variety of system-level Microsoft performance counters.

The module was created in response to customer requests for Powershell sample code using the CopperEgg API.

## Recent Updates:  
version 0.9.2 
Fixed the uncommented-comment in win_ctrs.txt, and updated CopperEgg.psm1 to fix a problem when sending metrics.

version 0.9.1
This release includes the capability to create user-defined metrics ... metrics that you create to monitor your application or infrastructure.
A sample dashboard and two metrics are provided to get you started by monitoring any of your background tasks, and their return codes. Check out
win_counters.txt, and the UserDefined.psm1 module for more info!

## Requirements
This release requires Powershell v3.0, which ships with Windows 8 and Windows Server 2012.
It has also been tested on Windows Server 2008r2 and Windows 7, with Powershell v3.0 installed.

You can download Powershell v3.0 here:
* [Microsoft Powershell v3.0](http://www.microsoft.com/en-us/download/details.aspx?id=34595)

A CopperEgg account is also required. If you don't have one yet, check it out:
* [CopperEgg Corporation](http://copperegg.com)

## Installation

* Clone this repository.

```ruby
git clone git://github.com/CopperEgg/revealmetrics-powershell.git
```
* Copy the CopperEgg-powershell.zip to the system you want to monitor. Before unzipping the archive, Right-click on Properties, and 'Unblock' the archive.

* Start Windows Powershell, running as Administrator

* Set the ExecutionPolicy to RemoteSigned (if you haven't already):

```ruby
Set-ExecutionPolicy RemoteSigned
```
* Create the installation directory, and cd to that directory:

```ruby
New-Item 'c:\Program Files (x86)\CopperEgg\Modules\CopperEgg' -type directory
cd 'c:\Program Files (x86)\CopperEgg\Modules\CopperEgg'
```
* Create a Powershell profile. If you have already set up a Powershell profile, skip this step.

There are a number of different profiles used by Powershell and PowershellISE, and they are in different places. :(
To see the choices, enter the following:

```ruby
$PROFILE | Format-List * -Force
```
The following instructions assume that you will create and edit the AllUsersAllHosts profile:

```ruby
new-item $PROFILE.AllUsersAllHosts -ItemType file -Force
```
* Edit your powershell profile to include a path to the CopperEgg module directory. Add the following line to your powershell profile:

```ruby
Set-Location "c:\Program Files (x86)\CopperEgg\Modules\CopperEgg"
$env:PSModulePath = $env:PSModulePath + ";c:\Program Files (x86)\CopperEgg\Modules\CopperEgg\"
```

* Unzip the CopperEgg-powershell.zip file to "c:\Program Files (x86)\CopperEgg\Modules\CopperEgg".

* Edit the CopperEgg_APIKEY.txt file, and replace the text therein with your CopperEgg API key, which you will find in the CopperEgg UI, under Settings.
Save the file, and close it.

## Usage

####Load the CopperEgg module:

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
Now go have a look at your CopperEgg UI, and you will see your new dashboards up and running!

####To stop monitoring:
```ruby
Stop-CopperEggMonitor
```

####To remove all loaded CopperEgg modules:
```ruby
Remove-AllCopperEgg
```

##Next Steps

The metrics monitored are selected using the win_counters.txt file. You will find notes there about the formatting, and additional detail will be found in Initialize-MetricGroups.ps1
The dashboards are built in Initialize-Dashboards.ps1. Use that code as a starting point for creating views exactly as you want them.


##To Run Your CopperEgg-StartMonitor.ps1 script 'as a service'

Specifically, these instructions are for ensuring that your monitoring powershell scripts resume running after restart or power-cycle. At this point, we do not support running the Powershell scripts as a Windows Service ... but using the Windows Task Scheduler, you can do very close to the same thing.

* As Administrator, enter the Task Scheduler (COntrol Panel-> Administrative Tools->Task Scheduler)

* Create Task General
  - Name CopperEggTask
  - When running the task, use the Administrator account.
  - Run whether user is logged in or not
  - Run with Highest Privelages
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
  - If the task is already running,

Close the Task Scheduler. CopperEggTask.ps1 should start (if not already started) within 5 minutes.


## Questions / Problems?

You can find detailed documentation of the CopperEgg API here:
* [CopperEgg API](http://dev.copperegg.com/)

##  LICENSE

(The MIT License)

Copyright © 2012 [CopperEgg Corporation](http://copperegg.com)

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
