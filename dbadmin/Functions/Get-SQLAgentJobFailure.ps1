function Get-SQLAgentJobFailure {
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
    ValueFromPipelineByPropertyName=$False,
      HelpMessage='What SQL instance name would you like to target?')]
    [Alias('server ')]
    [ValidateLength(3,30)]
    [string]$sqlinstance
  )

  begin {
    
    #uncomment if not loading from dbadmin
    #write-verbose "Creating Datatable and loading SMO"
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

    $AgentFailureQuery = @"
 SELECT @@SERVERNAME as [Instance]
	,sj1.job_id AS [JobID]
	, sjh1.step_id AS [StepID]
	, sj1.name AS [JobName]
	,sjh1.step_name AS [StepName]                 
	,CASE sjh1.run_status
	WHEN        0        THEN        'Failed'
	WHEN        1        THEN        'Succeeded'
	WHEN        2        THEN        'Retry'
	WHEN        3        THEN        'Canceled'
	WHEN        4        THEN        'In progress'
	ELSE ''
	END
	AS [Status]
	,sj1.LastRunTime
	,sjh1.message AS [Message]
	,RIGHT(sjs.output_file_name,CHARINDEX('\',REVERSE(sjs.output_file_name))-1) as [LogFile]

/*		Get the latest run for each job		*/
FROM	(SELECT MAX (msdb.dbo.agent_datetime(sjh.run_date, sjh.run_time)) AS LastRunTime
				,sj.job_id
				,sj.name
		FROM	msdb.dbo.sysjobs sj
		JOIN	msdb.dbo.sysjobhistory sjh ON sj.job_id = sjh.job_id
		WHERE	sjh.step_id = 0
		GROUP BY sj.job_id, sj.name) sj1

/*		Get the full details for that latest run	*/
INNER JOIN .msdb.dbo.sysjobhistory sjh1
ON		sj1.job_id = sjh1.job_id
AND		sjh1.step_id > 0
AND		msdb.dbo.agent_datetime(sjh1.run_date, sjh1.run_time) >= sj1.LastRunTime
AND		sjh1.run_status IN (0,3)						-- This is outcome of the job step
LEFT JOIN msdb.dbo.sysjobsteps sjs ON sjh1.job_id = sjs.job_id AND sjh1.step_name = sjs.step_name
ORDER BY	sj1.name
"@
  } #End on Begin

  process {

        write-verbose "Beginning process loop"

        Try {
            $server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $sqlinstance
            $server.ConnectionContext.Connect()
            $db = $server.Databases["msdb"]
        }
        Catch {
            Write-Error "Could not connect to [msdb] on $sqlinstance" -Category ConnectionError
        }
        write-verbose $server.name

        $FailureDetails = ($db.ExecuteWithResults($AgentFailureQuery)).Tables[0];

        foreach ($detail in $FailureDetails)
		{
            [pscustomobject]@{
                Instance = $detail.Instance 
                JobID = [GUID]$detail.JobID; 
                JobName = $detail.JobName;
                StepID = [Int32]$detail.StepID;  
                StepName = $detail.StepName; 
                Status =  $detail.Status;
                LastRunTime = [DateTime]$detail.LastRunTime;
                Message = $detail.Message; 
                LogFile =  $detail.LogFile
            }
        }

       
    } # End of Process

}