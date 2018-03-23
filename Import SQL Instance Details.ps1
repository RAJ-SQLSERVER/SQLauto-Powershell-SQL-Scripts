Import-Module E:\Powershell\Scripts\Modules\dbadmin
Import-Module E:\Powershell\Scripts\Modules\dbatools

<#
CREATE TABLE [dbo].[DBA_SQLInstanceDetails](
	[MachineName] [nvarchar](128) NULL,
	[WindowsName] [nvarchar](128) NULL,
	[WindowsVersion] [nvarchar](128) NULL,
	[PhysicalMemoryGB] [int] NULL,
	[CPUSockets] [int] NULL,
	[PhysicalCores] [int] NULL,
	[LogicalCores] [int] NULL,
	[ServerName] [nvarchar](128) NULL,
	[Instance] [nvarchar](128) NULL,
	[IsClustered] [int] NULL,
	[ComputerNamePhysicalNetBIOS] [nvarchar](128) NULL,
	[SQLVersion] [varchar](18) NULL,
	[Edition] [nvarchar](128) NULL,
	[ProductLevel] [nvarchar](128) NULL,
	[ProductUpdateLevel] [nvarchar](128) NULL,
	[ProductVersion] [nvarchar](128) NULL,
	[ProductMajorVersion] [int] NULL,
	[ProductMinorVersion] [int] NULL,
	[ProductBuild] [int] NULL,
	[ProductBuildType] [nvarchar](128) NULL,
	[ProductUpdateReference] [nvarchar](128) NULL,
	[ProcessID] [int] NULL,
	[Collation] [nvarchar](128) NULL,
	[IsFullTextInstalled] [int] NULL,
	[IsIntegratedSecurityOnly] [int] NULL,
	[FilestreamConfiguredLevel] [int] NULL,
	[IsHadrEnabled] [int] NULL,
	[HadrManagerStatus] [int] NULL,
	[InstanceDefaultDataPath] [nvarchar](256) NULL,
	[InstanceDefaultLogPath] [nvarchar](256) NULL,
	[BuildCLRVersion] [nvarchar](128) NULL,
	[CaptureDate] [datetime2](3) NOT NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[DBA_SQLInstanceDetails] ADD  CONSTRAINT [DF_CaptureDate]  DEFAULT (getdate()) FOR [CaptureDate]
GO
#>

$sqlinstance = "<sqlserver>"
$database = "<databasename>"

Try {
    $server = New-Object "Microsoft.SqlServer.Management.Common.ServerConnection" $sqlinstance
    $server.DatabaseName = $database
    $server.Connect()
}
Catch {
    Write-Error "Error: Could not connect to $sqlinstance"
}


$sqlinstances = Get-SQLCMSInstance -CentralManagementServer SQLMONITOR02 | Where {$_.FullGroupPath -match 'All Servers'} | Select Instance -Unique

$dt = $sqlinstances | %{ Get-SQLInstanceDetails -SqlInstance $_.Instance} | Select *, @{Name="CaptureDate";Expression={$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")}} | Out-DataTable

Invoke-SQLBulkCopy -dataTable $dt -table "DBA_SQLInstanceDetails" -Connection $server.ConnectionString

$dt | Out-GridView
