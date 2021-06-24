function Invoke-CheckSQLDBStatus {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    #Get status of each database
    $server = Get-SqlConnection $targetServer

    $cmd = @"
		SELECT [name] AS [database_name], state_desc FROM sys.databases d
    JOIN sys.database_mirroring dm ON d.database_id = dm.database_id
    WHERE dm.mirroring_role_desc <> 'MIRROR'
    OR dm.mirroring_role_desc IS NULL;
"@
    try {
        $results = $server.ExecuteWithResults($cmd)
    }
    catch {
        Get-Error $_ -ContinueAfterError
    }

    #Display the results to the console
    if ($results.Tables[0] | Where-Object {$_.state_desc -eq 'SUSPECT'}) {
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
    }
    elseif ($results.Tables[0] | Where-Object {$_.state_desc -in 'RESTORING','RECOVERING','RECOVERY_PENDING','EMERGENCY','OFFLINE','COPYING','OFFLINE_SECONDARY'}) {
        Write-Host "`nWARNING:" -BackgroundColor Yellow -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
    }
    else { Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)" }

    $results.Tables[0] | Where-Object {$_.state_desc -in 'SUSPECT','RESTORING','RECOVERING','RECOVERY_PENDING','EMERGENCY','OFFLINE','COPYING','OFFLINE_SECONDARY'} | Select-Object database_name,state_desc | Format-Table -AutoSize
} #Get-DatabaseStatus