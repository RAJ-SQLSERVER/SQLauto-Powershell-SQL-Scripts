function Get-SQLInstanceDetails {
  <#
  .SYNOPSIS
  Describe the function here
  .DESCRIPTION
  Describe the function in more detail
  .EXAMPLE
  Give an example of how to use it
  .EXAMPLE
  Give another example of how to use it
  .PARAMETER computername
  The computer name to query. Just one.
  .PARAMETER logname
  The name of a file to write failed computer names to. Defaults to errors.txt.
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
      HelpMessage='What SQL instance name would you like to target?')]
    [Alias('server ')]
    [ValidateLength(3,40)]
    [string]$sqlinstance,
    [switch]$simple
  )

  begin {
    #Query to get version of currrent MCM database
    [String]$InstanceDetailsQuery = @"
-- Get selected server properties (Query 3) (Server Properties)
SELECT 
'MachineName'					=SERVERPROPERTY('MachineName') ,
'ServerName'						=SERVERPROPERTY('ServerName') ,
'Instance'						=SERVERPROPERTY('InstanceName') ,
'IsClustered'					=SERVERPROPERTY('IsClustered') ,
'ComputerNamePhysicalNetBIOS'	=SERVERPROPERTY('ComputerNamePhysicalNetBIOS') ,
'SQLVersion'	=CASE SUBSTRING(CAST(serverproperty('ProductVersion') AS nvarchar),1,CHARINDEX('.',CAST(serverproperty('ProductVersion') AS nvarchar))-1)
								WHEN 8	THEN 'SQL 2000'
								WHEN 9	THEN 'SQL 2005'
								WHEN 10	THEN 'SQL 2008 / 2008 R2'
								WHEN 11	THEN 'SQL 2012'
								WHEN 12	THEN 'SQL 2014'
								WHEN 13	THEN 'SQL 2016' END ,
'Edition'						=SERVERPROPERTY('Edition') ,
'ProductLevel'					=SERVERPROPERTY('ProductLevel') ,
'ProductUpdateLevel'				=SERVERPROPERTY('ProductUpdateLevel') ,
'ProductVersion'					=SERVERPROPERTY('ProductVersion') ,
'ProductMajorVersion'			=SERVERPROPERTY('ProductMajorVersion') ,
'ProductMinorVersion'			=SERVERPROPERTY('ProductMinorVersion') ,
'ProductBuild'					=SERVERPROPERTY('ProductBuild') ,
'ProductBuildType'				=SERVERPROPERTY('ProductBuildType') ,
'ProductUpdateReference'			=SERVERPROPERTY('ProductUpdateReference') ,
'ProcessID'						=SERVERPROPERTY('ProcessID') ,
'Collation'						=SERVERPROPERTY('Collation') ,
'IsFullTextInstalled'			=SERVERPROPERTY('IsFullTextInstalled') ,
'IsIntegratedSecurityOnly'		=SERVERPROPERTY('IsIntegratedSecurityOnly') ,
'FilestreamConfiguredLevel'		=SERVERPROPERTY('FilestreamConfiguredLevel') ,
'IsHadrEnabled'					=SERVERPROPERTY('IsHadrEnabled')  ,
'HadrManagerStatus'				=SERVERPROPERTY('HadrManagerStatus') ,
'InstanceDefaultDataPath'		=SERVERPROPERTY('InstanceDefaultDataPath') ,
'InstanceDefaultLogPath'			=SERVERPROPERTY('InstanceDefaultLogPath') ,
'BuildCLRVersion'				=SERVERPROPERTY('BuildClrVersion')
"@

    [String]$InstanceDetailsQueryPre2012 = @"
-- Get selected server properties (Query 3) (Server Properties)
SELECT 
'MachineName'					=SERVERPROPERTY('MachineName') ,
'ServerName'						=SERVERPROPERTY('ServerName') ,
'Instance'						=SERVERPROPERTY('InstanceName') ,
'IsClustered'					=SERVERPROPERTY('IsClustered') ,
'ComputerNamePhysicalNetBIOS'	=SERVERPROPERTY('ComputerNamePhysicalNetBIOS') ,
'SQLVersion'	=CASE SUBSTRING(CAST(serverproperty('ProductVersion') AS nvarchar),1,CHARINDEX('.',CAST(serverproperty('ProductVersion') AS nvarchar))-1)
								WHEN 8	THEN 'SQL 2000'
								WHEN 9	THEN 'SQL 2005'
								WHEN 10	THEN 'SQL 2008 / 2008 R2'
								WHEN 11	THEN 'SQL 2012'
								WHEN 12	THEN 'SQL 2014'
								WHEN 13	THEN 'SQL 2016' END ,
'Edition'						=SERVERPROPERTY('Edition') ,
'ProductLevel'					=SERVERPROPERTY('ProductLevel') ,
'ProductUpdateLevel'				=SERVERPROPERTY('ProductUpdateLevel') ,
'ProductVersion'					=SERVERPROPERTY('ProductVersion') ,
'ProductMajorVersion'			=SERVERPROPERTY('ProductMajorVersion') ,
'ProductMinorVersion'			=SERVERPROPERTY('ProductMinorVersion') ,
'ProductBuild'					=SERVERPROPERTY('ProductBuild') ,
'ProductBuildType'				=SERVERPROPERTY('ProductBuildType') ,
'ProductUpdateReference'			=SERVERPROPERTY('ProductUpdateReference') ,
'ProcessID'						=SERVERPROPERTY('ProcessID') ,
'Collation'						=SERVERPROPERTY('Collation') ,
'IsFullTextInstalled'			=SERVERPROPERTY('IsFullTextInstalled') ,
'IsIntegratedSecurityOnly'		=SERVERPROPERTY('IsIntegratedSecurityOnly') ,
'FilestreamConfiguredLevel'		=SERVERPROPERTY('FilestreamConfiguredLevel') ,
'IsHadrEnabled'					=SERVERPROPERTY('IsHadrEnabled')  ,
'HadrManagerStatus'				=SERVERPROPERTY('HadrManagerStatus') ,
'InstanceDefaultDataPath'		=SERVERPROPERTY('InstanceDefaultDataPath') ,
'InstanceDefaultLogPath'			=SERVERPROPERTY('InstanceDefaultLogPath') ,
'BuildCLRVersion'				=SERVERPROPERTY('BuildClrVersion')
"@

  }

  process {

        write-verbose "Beginning process loop"

        #Write-host $sqlinstance

        Try {
            $server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $sqlinstance
            $server.Refresh()
            $db = $server.Databases["master"]
        }
        Catch {
            Write-Warning "Could not connect to $sqlinstance"
        }

        $PhysicalServer =  $server.ComputerNamePhysicalNetBIOS

        if(-not $simple) {
            try {
                #Get CPU Information
                $cpuInfo = Get-WmiObject –class Win32_processor -ComputerName $PhysicalServer |  Group-Object systemname  | %{ 
                New-Object psobject -Property @{
                        Item = $_.name
                        NumberOfCores = ($_.group | Measure-Object numberofcores -Sum).Sum
                        NumberOfLogicalProcessors = ($_.group | Measure-Object NumberOfLogicalProcessors -Sum).Sum
                        NumberOfSockets = $_.count
                    }
                }

                #Get OS Information 
                $OSInfo = Get-WmiObject Win32_OperatingSystem -ComputerName $PhysicalServer 

                #Get Memory Information. The data will be shown in a table as MB, rounded to the nearest second decimal. 
                $PhysicalMemory = Get-WmiObject CIM_PhysicalMemory -ComputerName $PhysicalServer | Measure-Object -Property capacity -Sum | % {[math]::round(($_.sum / 1GB),2)} 
            }
            catch {
                Write-Warning "Warning: Failed to gather information via wmi query"
            }
        }

        If($server.VersionMajor -gt 10) {
            $InstanceDetails = ($db.ExecuteWithResults($InstanceDetailsQuery)).Tables[0];
        }
        Else  {
            $InstanceDetails = ($db.ExecuteWithResults($InstanceDetailsQueryPre2012)).Tables[0];
        }
        foreach ($detail in $InstanceDetails)
			{
                if($simple) {
                    [pscustomobject]@{
                        MachineName = $detail.MachineName;
                        ServerName = $detail.ServerName;
                        Instance = $detail.Instance; 
                        IsClustered = $detail.IsClustered;
                        ComputerNamePhysicalNetBIOS = $detail.ComputerNamePhysicalNetBIOS;
                        SQLVersion = $detail.SQLVersion;
                        Edition = $detail.Edition;
                        ProductLevel = $detail.ProductLevel;
                        }
                }
                else {
                    [pscustomobject]@{
                        MachineName = $detail.MachineName;
                        WindowsName = $OSInfo.Caption
                        WindowsVersion = $OSInfo.Version
                        PhysicalMemoryGB = [Nullable[int]] $PhysicalMemory
                        CPUSockets = [Nullable[int]] $cpuInfo.NumberOfSockets
                        PhysicalCores = [Nullable[int]] $cpuInfo.NumberOfCores
                        LogicalCores = [Nullable[int]] $cpuInfo.NumberOfLogicalProcessors
                        ServerName = $detail.ServerName;
                        Instance = $detail.Instance; 
                        IsClustered = $detail.IsClustered;
                        ComputerNamePhysicalNetBIOS = $detail.ComputerNamePhysicalNetBIOS;
                        SQLVersion = $detail.SQLVersion;
                        Edition = $detail.Edition;
                        ProductLevel = $detail.ProductLevel;
                        ProductUpdateLevel = $detail.ProductUpdateLevel;
                        ProductVersion = $detail.ProductVersion;
                        ProductMajorVersion = $detail.ProductMajorVersion;
                        ProductMinorVersion = $detail.ProductMinorVersion;
                        ProductBuild = $detail.ProductBuild;
                        ProductBuildType = $detail.ProductBuildType;
                        ProductUpdateReference = $detail.ProductUpdateReference;
                        ProcessID = $detail.ProcessID;
                        Collation = $detail.Collation;
                        IsFullTextInstalled = $detail.IsFullTextInstalled;
                        IsIntegratedSecurityOnly = $detail.IsIntegratedSecurityOnly;
                        FilestreamConfiguredLevel = $detail.FilestreamConfiguredLevel;
                        IsHadrEnabled = $detail.IsHadrEnabled;
                        HadrManagerStatus = $detail.HadrManagerStatus;
                        InstanceDefaultDataPath = $detail.InstanceDefaultDataPath;
                        InstanceDefaultLogPath = $detail.InstanceDefaultLogPath;
                        BuildClrVersion = $detail.BuildClrVersion;
                    }
                }
            }

    } # End of Process

}
