FUNCTION Get-SQLRunningJobs
{
<#
.SYNOPSIS
Gets SQL Agent Job information for each instance(s) of SQL Server.

.DESCRIPTION
 The Get-DbaAgentJob returns connected SMO object for SQL Agent Job information for each instance(s) of SQL Server.
	
.PARAMETER SqlInstance
SQL Server name or SMO object representing the SQL Server to connect to. This can be a collection and recieve pipeline input to allow the function
to be executed against multiple SQL Server instances.

.PARAMETER SqlCredential
SqlCredential object to connect as. If not specified, current Windows login will be used.

.NOTES
Author: Garry Bargsley (@gbargsley), http://blog.garrybargsley.com

Modified from original to only getting currently running agent jobs

.EXAMPLE
Get-DbaAgentJob -SqlInstance localhost
Returns all SQL Agent Job on the local default SQL Server instance

.EXAMPLE
Get-DbaAgentJob -SqlInstance localhost, sql2016
Returns all SQl Agent Job for the local and sql2016 SQL Server instances

#>
	[CmdletBinding()]
	Param (
		[parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
		[Alias("ServerInstance", "SqlServer")]
		[object[]]$SqlInstance,
		[System.Management.Automation.PSCredential]$SqlCredential
	)
	
	PROCESS
	{
		foreach ($instance in $SqlInstance)
		{
			Write-Verbose "Attempting to connect to $instance"
			try
			{
                #Reference SMO Assembly
                #Run on SQLMONITOR02 as the assemblies are installed on that server.
                [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.smo") | out-null
				$server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $instance
			}
			catch
			{
				Write-Warning "Can't connect to $instance or access denied. Skipping."
				continue
			}
			
			foreach ($agentJob in $server.JobServer.Jobs | Where {$_.CurrentRunStatus -ne "Idle"})
			{
				[pscustomobject]@{
                    Instance = $instance; 
                    JobName = $agentJob.Name;
                    Category = $agentJob.Category
                    LastRunDate = $agentJob.LastRunDate;
                    CurrentRunStatus = $agentJob.CurrentRunStatus;
                }
			}
		}
	}
}
