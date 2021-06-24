function Invoke-CheckAGStatus {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    $server = Get-SqlConnection $targetServer

    $cmd = @"
    SELECT 
	     ag.name AS ag_name
	    ,ar.replica_server_name
	    ,ars.role_desc AS role
	    ,ar.availability_mode_desc
	    ,ar.failover_mode_desc
	    ,adc.[database_name]
	    ,drs.synchronization_state_desc AS synchronization_state
	    ,drs.synchronization_health_desc AS synchronization_health
    FROM sys.dm_hadr_database_replica_states AS drs WITH (NOLOCK)
    INNER JOIN sys.availability_databases_cluster AS adc WITH (NOLOCK) ON drs.group_id = adc.group_id AND drs.group_database_id = adc.group_database_id
    INNER JOIN sys.availability_groups AS ag WITH (NOLOCK) ON ag.group_id = drs.group_id
    INNER JOIN sys.availability_replicas AS ar WITH (NOLOCK) ON drs.group_id = ar.group_id AND drs.replica_id = ar.replica_id
    INNER JOIN sys.dm_hadr_availability_replica_states AS ars ON ar.replica_id = ars.replica_id
    WHERE ars.is_local = 1
    ORDER BY ag.name, ar.replica_server_name, adc.[database_name] OPTION (RECOMPILE);
"@

    #If one exists, get status of each Availability Group
    try {
        $results = $server.ExecuteWithResults($cmd)
    }
    catch {
        Get-Error $_ -ContinueAfterError
    }

    #Display the results to the console
    if ($results.Tables[0].Rows.Count -ne 0) {
        if ($results.Tables[0] | Where-Object {$_.synchronization_health -ne 'HEALTHY'}) {
            if ($_.synchronization_health -eq 'NOT_HEALTHY') {
                Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
            }
            elseif ($_.synchronization_health -eq 'PARTIALLY_HEALTHY') {
                Write-Host "`nWARNING:" -BackgroundColor Yellow -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
            }
        }
        else {
            Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
        }

        $results.Tables[0] | Where-Object {$_.synchronization_health -in 'NOT_HEALTHY','PARTIALLY_HEALTHY'} | Select-Object ag_name,role,database_name,synchronization_state,synchronization_health | Format-Table -AutoSize
    }
    else {
      Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
      Write-Host '*** No Availabiliy Groups detected ***'
    }
} #Get-AGStatus