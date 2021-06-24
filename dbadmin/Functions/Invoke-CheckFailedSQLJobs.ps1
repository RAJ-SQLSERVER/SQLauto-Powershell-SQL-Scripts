function Invoke-CheckFailedSQLJobs {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    $server = Get-SqlConnection $targetServer

    $cmd = @"
    SELECT 
	    j.name AS job_name
	    ,CASE
		    WHEN a.start_execution_date IS NULL THEN 'Not Running'
		    WHEN a.start_execution_date IS NOT NULL AND a.stop_execution_date IS NULL THEN 'Running'
		    WHEN a.start_execution_date IS NOT NULL AND a.stop_execution_date IS NOT NULL THEN 'Not Running'
	        END AS 'current_run_status'
	    ,a.start_execution_date AS 'last_start_date'
	    ,a.stop_execution_date AS 'last_stop_date'
	    ,CASE h.run_status
		    WHEN 0 THEN 'Failed'
		    WHEN 1 THEN 'Succeeded'
		    WHEN 2 THEN 'Retry'
		    WHEN 3 THEN 'Canceled'
	        END AS 'last_run_status'
	    ,h.message AS 'job_output'
    FROM msdb.dbo.sysjobs j
    INNER JOIN msdb.dbo.sysjobactivity a ON j.job_id = a.job_id
    LEFT JOIN msdb.dbo.sysjobhistory h ON a.job_history_id = h.instance_id
    WHERE a.session_id = (SELECT MAX(session_id) FROM msdb.dbo.sysjobactivity)
		AND j.enabled = 1
    ORDER BY j.name;
"@

    #Get the failed jobs and store it in the repository
    try {
        $results = $server.ExecuteWithResults($cmd)
    }
    catch {
        Get-Error $_ -ContinueAfterError
    }

    #Display the results to the console
    if ($results.Tables[0] | Where-Object {$_.last_run_status -eq 'Failed'}) {
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
    }
    elseif ($results.Tables[0] | Where-Object {$_.last_run_status -in 'Retry','Canceled'}) {
        Write-Host "`nWARNING:" -BackgroundColor Yellow -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
    }
    else {
      Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
    }

    $results.Tables[0] | Where-Object {$_.last_run_status -in 'Failed','Retry','Canceled'} | Select-Object job_name,current_run_status,last_run_status,last_stop_date | Format-Table -AutoSize
} #Get-FailedJobs