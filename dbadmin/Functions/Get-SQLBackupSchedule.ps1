function Get-SQLBackupSchedule {
  <#
  .SYNOPSIS
  Gets the backup schedule for an instance of SQL server.
  .DESCRIPTION
  Connects to the instance specified and runs a query to determine which databases to backup based on a set of rules
  System Databases always Full
  Full backup once a week on the day specified
  Full backup if no full backup has taken place in 7 days
  Full backup if the differential chain has been broken
  Differential backup all other times.
  .NOTES
  Tags: DisasterRecovery, Backup, Restore
  Original Author: Ian Pain  
  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
  You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
  .EXAMPLE
  Get-SQLBackupSchedule -sqlinstance SQL2016 -WeeklyBackupDay Saturday -BackupSetName "Daily Diff Backups"
  .PARAMETER sqlinstance
  The SQL instance to get the backup schedule from.
  .PARAMETER WeeklyBackupDay
  The day of the week to take the weekly full backup on.
  .PARAMETER BackupSetName
  The name you wish to assign to the backup set
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
      HelpMessage='What computer name would you like to target?')]
    [Alias('instance')]
    [ValidateLength(3,30)]
    [string[]]$sqlinstance,
    [ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday','Saturday','Sunday')]
	[string]$FullBackupDay = "Saturday",
    [String]$BackupSetName = '',
    [String[]]$Exclude,
    [String[]]$Include,
    [switch]$systemonly = $false
  )

  begin {
    write-verbose "Setting variables . . ."

    If($exclude) { $exclude =  "'Tempdb','$(($exclude).replace(',',''','''))'"}
    else {$exclude =  "'Tempdb'"}

    If($include) { $includeFilter =  "(sysdb.name IN ('$(($include).replace(',',''','''))') OR sysdb.database_id < 5 ) AND /*Always make sure system databases are being backed up*/"}

    [String]$BackupQuery = @"
DECLARE @WeeklyBackupDay VARCHAR(6)
DECLARE @systemonly bit = '$systemonly'

SELECT @WeeklyBackupDay =  CASE WHEN DATENAME(WEEKDAY,GETDATE()) = '$FullBackupDay' THEN 'TRUE' ELSE 'FALSE' END

SELECT [name],[BackupType],ISNULL(BACKUP_FILES,1) as [BackupFiles] FROM (
SELECT sysdb.name
, CASE 
WHEN @WeeklyBackupDay = 'TRUE' THEN 'D' --Full Backup on the day when weekly backup have been set
WHEN @WeeklyBackupDay = 'TRUE' AND sysdb.is_read_only = 1 THEN 'D' --If database read only only take a full backup on weekly backup day
WHEN sysdb.database_id < 5 THEN 'D' --Always do a Full backup for system databases
WHEN mf.differential_base_lsn IS NULL OR (dbl.differential_base_lsn <> mf.differential_base_lsn) THEN 'D' --Full backup if differential chain has broken or no previous first full backup
WHEN sysdb.database_id >=5 AND sysdb.is_read_only = 0 AND ISNULL(DATEDIFF(DAY,backup_start_date,CAST(getdate() as DATE)),99) < 7 THEN 'I' --Differential backup on all other days
WHEN sysdb.database_id >=5 AND sysdb.is_read_only = 0 AND ISNULL(DATEDIFF(DAY,backup_start_date,CAST(getdate() as DATE)),99) >= 7 THEN 'D' --Full Backup if last full backup greater than 7 days (catch all if weekly job fails)       
ELSE NULL 
END AS [BackupType]
FROM master.sys.databases sysdb
INNER JOIN master.sys.master_files mf ON mf.database_id = sysdb.database_id AND ( mf.file_id <> '2' AND mf.file_id = 1)
LEFT JOIN ( 
		-- Get the date of the last full backup
		SELECT b.database_name
		,MAX(backup_start_date) AS backup_start_date
		FROM msdb..backupset b 
		WHERE b.type = 'D' AND b.is_copy_only = 0 AND server_name = @@SERVERNAME AND ISNULL(name,'') = '$BackupSetName' 
		GROUP BY b.database_name
		) bs 
ON sysdb.name = bs.database_name
LEFT JOIN (
		-- Get differential_base_lsn / first_lsn to compare with masterfiles to look for change
		SELECT DISTINCT bs.database_name, da.differential_base_lsn,da.type
		FROM msdb..backupset bs
		OUTER APPLY (
				SELECT TOP 1 
				COALESCE(differential_base_lsn,checkpoint_lsn) as differential_base_lsn
				, [type]
				FROM msdb..backupset WHERE database_name = bs.database_name  ORDER BY backup_start_date DESC
				) da
		WHERE bs.is_copy_only = 0 AND server_name = @@SERVERNAME AND ISNULL(bs.name,'') = '$BackupSetName'
		) dbl 
ON dbl.database_name = sysdb.name
WHERE (sysdb.state_desc = 'ONLINE' AND source_database_id IS NULL AND sysdb.is_in_standby = 0)
AND (
	$includeFilter
	 sysdb.name NOT IN ($exclude)
	)
AND sysdb.database_id < CASE @systemonly WHEN 1 THEN 5 ELSE 9999 END
) R
OUTER APPLY (
		SELECT TOP 1
		CASE WHEN CAST(CAST(SERVERPROPERTY('ProductVersion') as VARCHAR(4)) as decimal(4,2)) >= 10.5 THEN
			CASE WHEN compressed_backup_size > 107374182400 THEN 10
			WHEN compressed_backup_size < 107374182400  AND compressed_backup_size > 10737418240 THEN CEILING(compressed_backup_size / 10737418240 )
			ELSE 1 END
		ELSE 
			CASE WHEN backup_size > 107374182400 THEN 10
			WHEN backup_size < 107374182400  AND backup_size > 10737418240 THEN CEILING(backup_size / 10737418240 )
			ELSE 1 END 
		END AS BACKUP_FILES 
		FROM msdb..backupset WHERE database_name = R.[name] AND [type] = R.[BackupType] ORDER BY backup_start_date DESC
		) da1
WHERE R.BackupType IS NOT NULL
"@
  }

  process {

        write-verbose "Beginning process loop"

        Try {
            $server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $sqlinstance
            $db = $server.Databases["msdb"]
        }
        Catch {
            Write-Error "Could not connect to [msdb] on $sqlinstance"
        }

        write-verbose $server.name

        $BackupSchedule = ($db.ExecuteWithResults($BackupQuery)).Tables[0];

        foreach ($detail in $BackupSchedule)
			{
                [pscustomobject]@{
                    Instance = $($sqlinstance);
                    DatabaseName = $detail.Name;
                    BackupType = $detail.BackupType;
                    BackupFiles = $detail.BackupFiles
                }
            }

    } # End of Process
}




