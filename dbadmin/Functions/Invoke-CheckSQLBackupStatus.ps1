function Invoke-CheckSQLBackupStatus {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    #Get status of each database
    $server = Get-SqlConnection $targetServer

    $cmd = @"
    SELECT 
	     name AS [database_name]
	    ,recovery_model_desc
	    ,[D] AS last_full_backup
	    ,[I] AS last_differential_backup
	    ,[L] AS last_tlog_backup
	    ,CASE
		    /* These conditions below will cause a CRITICAL status */
		    WHEN [D] IS NULL THEN 'CRITICAL'															-- if last_full_backup is null then critical
		    WHEN [D] < DATEADD(DD,-1,CURRENT_TIMESTAMP) AND [I] IS NULL THEN 'CRITICAL'								-- if last_full_backup is more than 2 days old and last_differential_backup is null then critical
		    WHEN [D] < DATEADD(DD,-7,CURRENT_TIMESTAMP) AND [I] < DATEADD(DD,-2,CURRENT_TIMESTAMP) THEN 'CRITICAL'				-- if last_full_backup is more than 7 days old and last_differential_backup more than 2 days old then critical
		    WHEN recovery_model_desc <> 'SIMPLE' AND name <> 'model' AND [L] IS NULL THEN 'CRITICAL'	-- if recovery_model_desc is SIMPLE and last_tlog_backup is null then critical
		    WHEN recovery_model_desc <> 'SIMPLE' AND name <> 'model' AND [L] < DATEADD(HH,-6,CURRENT_TIMESTAMP) THEN 'CRITICAL'		-- if last_tlog_backup is more than 6 hours old then critical
		    --/* These conditions below will cause a WARNING status */
		    WHEN [D] < DATEADD(DD,-1,CURRENT_TIMESTAMP) AND [I] < DATEADD(DD,-1,CURRENT_TIMESTAMP) THEN 'WARNING'		-- if last_full_backup is more than 1 day old and last_differential_backup is greater than 1 days old then warning
		    WHEN recovery_model_desc <> 'SIMPLE' AND name <> 'model' AND [L] < DATEADD(HH,-3,CURRENT_TIMESTAMP) THEN 'WARNING'		-- if last_tlog_backup is more than 3 hours old then warning
            /* Everything else will return a GOOD status */
		    ELSE 'GOOD'
	     END AS backup_status
	    ,CASE
		    /* These conditions below will cause a CRITICAL status */
		    WHEN [D] IS NULL THEN 'No FULL backups'															-- if last_full_backup is null then critical
		    WHEN [D] < DATEADD(DD,-1,CURRENT_TIMESTAMP) AND [I] IS NULL THEN 'FULL backup > 1 day; no DIFF backups'			-- if last_full_backup is more than 2 days old and last_differential_backup is null then critical
		    WHEN [D] < DATEADD(DD,-7,CURRENT_TIMESTAMP) AND [I] < DATEADD(DD,-2,CURRENT_TIMESTAMP) THEN 'FULL backup > 7 day; DIFF backup > 2 days'	-- if last_full_backup is more than 7 days old and last_differential_backup more than 2 days old then critical
		    WHEN recovery_model_desc <> 'SIMPLE' AND name <> 'model' AND [L] IS NULL THEN 'No LOG backups'	-- if recovery_model_desc is SIMPLE and last_tlog_backup is null then critical
		    WHEN recovery_model_desc <> 'SIMPLE' AND name <> 'model' AND [L] < DATEADD(HH,-6,CURRENT_TIMESTAMP) THEN 'LOG backup > 6 hours'		-- if last_tlog_backup is more than 6 hours old then critical
		    --/* These conditions below will cause a WARNING status */
		    WHEN [D] < DATEADD(DD,-1,CURRENT_TIMESTAMP) AND [I] < DATEADD(DD,-1,CURRENT_TIMESTAMP) THEN 'FULL backup > 7 day; DIFF backup > 1 day'		-- if last_full_backup is more than 1 day old and last_differential_backup is greater than 1 days old then warning
		    WHEN recovery_model_desc <> 'SIMPLE' AND name <> 'model' AND [L] < DATEADD(HH,-3,CURRENT_TIMESTAMP) THEN 'LOG backup > 3 hours'		-- if last_tlog_backup is more than 3 hours old then warning
            /* Everything else will return a GOOD status */
		    ELSE 'No issues'
	     END AS status_desc
    FROM (
	    SELECT
		     d.name
		    ,d.recovery_model_desc
		    ,bs.type
		    ,MAX(bs.backup_finish_date) AS backup_finish_date
	    FROM master.sys.databases d
	    LEFT JOIN msdb.dbo.backupset bs ON d.name = bs.database_name
	    WHERE (bs.type IN ('D','I','L') OR bs.type IS NULL)
	    AND d.database_id <> 2				-- exclude tempdb
	    AND d.source_database_id IS NULL	-- exclude snapshot databases
	    AND d.state NOT IN (1,6,10)			-- exclude offline, restoring, or secondary databases
	    AND d.is_in_standby = 0				-- exclude log shipping secondary databases
	    GROUP BY d.name, d.recovery_model_desc, bs.type
    ) AS SourceTable  
    PIVOT  
    (
	    MAX(backup_finish_date)
	    FOR type IN ([D],[I],[L])  
    ) AS PivotTable
    ORDER BY database_name;
"@
    
    try {
        $results = $server.ExecuteWithResults($cmd)
    }
    catch {
        Get-Error $_ -ContinueAfterError
    }

    #Display the results to the console
    if ($results.Tables[0] | Where-Object {$_.backup_status -eq 'CRITICAL'}) {
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
    }
    elseif ($results.Tables[0] | Where-Object {$_.backup_status -eq 'WARNING'}) {
        Write-Host "`nWARNING:" -BackgroundColor Yellow -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
    }
    else {
        Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
    }

    $results.Tables[0] | Where-Object {$_.backup_status -in 'CRITICAL','WARNING'} | Select-Object database_name,backup_status,status_desc | Format-Table -AutoSize

} #Get-DatabaseBackupStatus