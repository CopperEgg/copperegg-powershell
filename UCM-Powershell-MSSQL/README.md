UCM-Powershell
==============

This is a powershell based implementation to collect performance metrics from Microsoft SQL Server.
Unlike the implementation in main page of the repository, it does not collect metrics for other services but comes with
installation script because of which the user is not required to create config.xml file himself. To get
the installation script, open your Uptime Cloud Monitor account -> Custom Tab -> Getting Started -> Microsoft SQL Server and copy the script.
The script will be downloaded and you will be required to enter configuration settings for your SQL server instance(s).

##Synopsis
The module includes:
 - Create-Dashboards.ps1 : Creates dashboard when user requests to create (via -MakeDashboard option) and when configuring instances (during installation)
 - Create-MetricGroups.ps1 : Checks the existence of metric group everytime when the script starts and creates if not present.
 - Monitor-Worker.ps1 : Worker thread script. Say if you are monitoring 5 instances, 5 copies of this script run on your system (1 for each instance)
 - Start-UCM-Monitor.ps1 : Script for starting monitoring job based on settings inside config.xml
 - Stop-UCM-Monitor.ps1 : Script to stop monitoring job for all instances.
 - UCM-SQL-Monitor.ps1 : Reads configuration settings and calls Monitor-Worker for all the instances defined in config.xml
 - Utils.ps1 : Common utility functions are defined inside this file.
 - config-sample.xml : A sample config.xml, a usable config.xml file is created during installation. We don't recommend our users to change config.xml by hand unless they completely understand its structure. The structure is not too complex and you can play with it after taking the backup of main config.xml somewhere.
 - dashboard.json : A JSON request to create dashboard on UCM. Some values are configurable by the user and are picked from config.xml before sending request to create a dashboard.
 - metric_group.json :  A JSON request to create metric group on UCM. Some values are configurable by the user and are picked from config.xml before sending request to create a metric group.

This module provides a rich set of performance metrics for Microsoft SQL Server. The metrics monitored by this script are :

- Access Page Splits
- Cache Hit Ratio
- Checkpoint Pages
- Page Life Expectancy
- Batch Requests
- Connections
- Lock Waits
- Proc Blocked
- SQL Compilations
- SQL Recompilations
- Active parallel threads
- Active requests
- Active Transactions
- Backup/Restore Throughput/sec
- Blocked tasks
- Cache Object Counts
- CPU usage %
- Dropped Messages Total
- Errors/sec
- Free Memory (KB)
- Number of Deadlocks/sec
- Open Connection Count
- Page lookups/sec
- Page reads/sec
- Page Splits/sec
- Page writes/sec
- Queued requests
- Transaction Delay
- Transaction ownership waits
- Transactions
- Write Transactions/sec

This script monitors more metrics as compared to previous script which is in the main page of the repository.

All the errors and events are logged in C:\Program Files\UCM-Powershell\ucm-metrics.log

## Requirements
This release requires Powershell v3.0, which ships with Windows 8 and Windows Server 2012.

The script has been tested on:
- Windows 8 system and  SQL Server 2012
- Windows 10 system and SQL Server 2014
- Windows 10 system and SQL Server 2012

Prerequisites :
* Powershell v3.0, you can download it from [here](http://www.microsoft.com/en-us/download/details.aspx?id=34595)

* A Uptime Cloud Monitor account is also required. [IDERA](https://www.idera.com/infrastructure-monitoring-as-a-service/freetrialsubscriptionform)

* If you don't have Microsoft SQL Server installed on a system where you are installing this, you need to install 3 packages from microsoft so that SQL modules are available inside powershell. Use this [link] (http://www.microsoft.com/en-us/download/details.aspx?id=29065)
 Download and install these packages in this order only (choose x86 and x64 accordingly)
 1. Microsoft System CLR Types for Microsoft SQL Server 2012 (search SQLSysClrTypes.msi in the page)
 2. Microsoft SQL Server 2012 Shared Management Objects (search SharedManagementObjects.msi in the page)
 3. Microsoft Windows PowerShell Extensions for Microsoft SQL Server 2012 (search PowerShellTools.msi in the page)

 After downloading, run this command on a powershell window in Admin mode : Import-Module SQLPS

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
