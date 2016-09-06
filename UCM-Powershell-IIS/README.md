UCM-Powershell-IIS
==============

Uses powershell to monitor Microsoft based services. It currently supports
 - Microsoft IIS Server,

To get the installation script, open your Uptime Cloud Monitor account -> Custom Tab ->
Getting Started -> Click on Microsoft IIS Server and follow the instructions. The script will be downloaded
and you will be required to enter configuration settings for your instance(s). Post that,
a config.xml file is generated with the provided settings and service is started to monitor your instance(s)

##Synopsis
The module includes:
 - Create-Dashboards.ps1 : Creates dashboard when user requests to create (via -MakeDashboard option) and when configuring instances (during installation)
 - Create-MetricGroups.ps1 : Checks the existence of metric group everytime when the script starts and creates if not present.
 - Worker.ps1 : Worker thread script. Say if you are monitoring 5 instances, 5 copies of this script run on your system (1 for each instance)
 - Start-UCM-Monitor.ps1 : Script for starting monitoring job based on settings inside config.xml
 - Stop-UCM-Monitor.ps1 : Script to stop monitoring job for all instances.
 - UCM-SQL-Monitor.ps1 : Reads configuration settings and calls Worker for all the instances defined in config.xml
 - Utils.ps1 : Common utility functions are defined inside this file.
 - config-sample.xml : A sample config.xml, a usable config.xml file is created during installation. We don't recommend our users to change config.xml by hand unless they completely understand its structure.
 - dashboard.json : A JSON request to create dashboard on UCM. Some values are configurable by the user and are picked from config.xml before sending request to create a dashboard.
 - metric_group.json :  A JSON request to create metric group on UCM. Some values are configurable by the user and are picked from config.xml before sending request to create a metric group.

This module provides a rich set of performance metrics for Microsoft IIS Server. The metrics monitored by this script are :

- Current Anonymous Users
- Current CGI Requests
- Current Connections
- Current ISAPI Requests
- Current NonAnonymous Users
- Maximum CGI Requests
- Maximum Connections
- Maximum ISAPI Requests
- Service Uptime
- Bytes Recieved
- Bytes Sent
- CGI Request
- Isapi Extension Requests
- Lock Requests
- Locked Errors
- NonAnonymous Users
- NotFound Errors

All the errors and events are logged in C:\Program Files\UCM-Powershell\IIS\ucm-metrics.log

## Requirements

Make sure to update the firewall settings in remote system monitoring system. Here monitoring system is the one where you will be
installing and runing this script.

All of the above systems had powershell 3.0 installed. Apart from that, the script has following requirements

* Powershell v3.0 is required, you can download it from [here](http://www.microsoft.com/en-us/download/details.aspx?id=34595)
If you want to check your powershell version, open a powershell terminal and run

`$PSVersionTable.PSVersion`

This will show you Powershell major version, minor version etc.

* A Uptime Cloud Monitor account is also required. [IDERA](https://www.idera.com/infrastructure-monitoring-as-a-service/freetrialsubscriptionform)

* Enable IIS on Windows Server [here](http://www.iis.net/learn/application-frameworks/scenario-build-an-aspnet-website-on-iis/configuring-step-1-install-iis-and-asp-net-modules)

## Questions / Problems?

For any questions / suggestions, please contact support-uptimecm@idera.com

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
