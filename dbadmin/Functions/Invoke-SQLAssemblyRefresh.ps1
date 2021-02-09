function Invoke-SQLAssemblyRefresh {
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
    [ValidateLength(3,30)]
    [string]$instance,
	[string]$database
  )

  begin {
    
    #uncomment if not loading from dbadmin
    #write-verbose "Creating Datatable and loading SMO"
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

    $IndexQuery = @"
DECLARE @AssemblyName VARCHAR(255),
        @AssemblyLocation VARCHAR(255),
		@AssemblyVersion VARCHAR(50),
        @AlterAssemblyCommand NVARCHAR(1024),
        @DotNetFolder NVARCHAR(255)
 
/* 
SELECT CASE WHEN CAST(SERVERPROPERTY('Edition') AS VARCHAR(1000)) LIKE '%(64-bit)%' THEN 1 ELSE 0 END as [Check]
SELECT * FROM sys.dm_clr_properties 
SELECT * FROM sys.assemblies
SELECT * FROM sys.assembly_files
*/

IF OBJECT_ID('tempdb..#DotNetFolder') IS NOT NULL DROP TABLE #DotNetFolder

CREATE TABLE #DotNetFolder (
	[version] varchar(25),
	[path] varchar(255)
)

IF ( CAST(SERVERPROPERTY('Edition') AS VARCHAR(1000)) LIKE '%(64-bit)%' )
	INSERT INTO #DotNetFolder SELECT * FROM (VALUES('version=2.0.0.0','C:\Windows\Microsoft.NET\Framework64\v2.0.50727\'),('version=4.0.0.0','C:\Windows\Microsoft.NET\Framework64\v4.0.30319\'),('version=3.0.0.0','C:\Program Files\Reference Assemblies\Microsoft\Framework\v3.0\'),('version=3.5.0.0','C:\Program Files\Reference Assemblies\Microsoft\Framework\v3.5\') )d([version],[path])
ELSE 
	SELECT * FROM (VALUES('2.0.0.0','C:\Windows\Microsoft.NET\Framework\v2.0.50727\'),('4.0.0.0','C:\Windows\Microsoft.NET\Framework\v4.0.30319\'),('version=3.0.0.0','C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\v3.0\'),('version=3.5.0.0','C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\v3.5\') )d([version],[path])

IF OBJECT_ID('tempdb..#Results') IS NOT NULL DROP TABLE #Results

CREATE TABLE #Results (
		ServerName varchar(128),
		DatabaseName varchar(128),
        AssemblyName VARCHAR(255),
		AssemblyVersion varchar(50),
        AssemblyLocation VARCHAR(255),
        AlterAssemblyCommand NVARCHAR(1024),
        Results VARCHAR(1024)
)
 
DECLARE Commands CURSOR FAST_FORWARD FOR
select sa.name as AssemblyName,
		SUBSTRING(clr_name,PATINDEX('%version%',clr_name),CHARINDEX(',',clr_name,PATINDEX('%version%',clr_name))-PATINDEX('%version%',clr_name))  as [Version],
        saf.name as Assemblylocation,
        case when charindex(':\', saf.name) = 2
            then 'ALTER ASSEMBLY [' + sa.name + '] FROM ''' + saf.name
            else 'ALTER ASSEMBLY [' + sa.name + '] FROM ''' +  dnf.path COLLATE Latin1_General_CI_AS + saf.name
        end + (case right(saf.name, 4) when '.dll' then '' else '.dll' end) + ''''
        as AlterAssemblyCommand
from sys.assemblies sa 
inner join sys.assembly_files saf  on sa.assembly_id = saf.assembly_id
left join #DotNetFolder dnf on dnf.version COLLATE Latin1_General_CI_AS = SUBSTRING(clr_name,PATINDEX('%version%',clr_name),CHARINDEX(',',clr_name,PATINDEX('%version%',clr_name))-PATINDEX('%version%',clr_name)) COLLATE Latin1_General_CI_AS
where sa.name <> ('Microsoft.SqlServer.Types')
  and (sa.name like 'System.%' or sa.name like 'microsoft.%')
 
OPEN Commands
 
FETCH NEXT FROM Commands
INTO @AssemblyName,
		@AssemblyVersion,
		@AssemblyLocation,
		@AlterAssemblyCommand
 
WHILE @@FETCH_STATUS = 0
BEGIN
 
    BEGIN TRY
        exec sp_executesql @AlterAssemblyCommand
		INSERT INTO #Results SELECT @@SERVERNAME, DB_NAME(), @AssemblyName, @AssemblyVersion, @AssemblyLocation, @AlterAssemblyCommand, 'Assembly refreshed successfully'
    END TRY
    BEGIN CATCH
		INSERT INTO #Results
        SELECT @@SERVERNAME, 
				DB_NAME(),
				@AssemblyName,
				@AssemblyVersion,
                @AssemblyLocation,
                @AlterAssemblyCommand,
                CASE ERROR_NUMBER()
                    WHEN 6285 THEN 'No update necessary (MVID match)'
                    WHEN 6501 THEN 'Physical assembly not found at specified location (SQL Error 6501)'
                    ELSE ERROR_MESSAGE() + ' (SQL Error ' + convert(varchar(10), ERROR_NUMBER()) + ')'
                END
 
    END CATCH
 
    FETCH NEXT FROM Commands
	INTO @AssemblyName,
			@AssemblyVersion,
			@AssemblyLocation,
			@AlterAssemblyCommand
 
END
 
CLOSE Commands
DEALLOCATE Commands

SELECT * FROM #Results

IF OBJECT_ID('tempdb..#Results') IS NOT NULL DROP TABLE #Results
IF OBJECT_ID('tempdb..#DotNetFolder') IS NOT NULL DROP TABLE #DotNetFolder
"@

  } #End on Begin

  process {

        write-verbose "Beginning process loop"

        $server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $instance
        write-verbose $server.name

        if ($database -ne "") {
            write-verbose "processing database parameter"
            $dbs = $server.Databases[$database]
        } else {
            write-verbose "No database parameter set processing all databases"
            $dbs = $server.Databases | Where {$_.Status -eq "Normal"}
        }

        if ($dbs) {   
            foreach ($db in $dbs) {
            write-verbose $db.Name
            $Results = ($db.ExecuteWithResults($IndexQuery)).Tables[0];
            foreach ($detail in $Results)
				{
                    [pscustomobject]@{
                        Instance = $instance; 
                        DatabaseName = $db.Name;
                        AssemblyName = $detail.AssemblyName; 
                        AssemblyVersion = $detail.AssemblyVersion;
                        AssemblyLocation = $detail.AssemblyLocation; 
                        AlterAssemblyCommand = $detail.AlterAssemblyCommand; 
                        Results =  $detail.Results;
                    }
                }

            }
        }
        Else {
            Write-Warning "Could not find a database called $database on $instance"
		    continue
        }
        
    } # End of Process

}