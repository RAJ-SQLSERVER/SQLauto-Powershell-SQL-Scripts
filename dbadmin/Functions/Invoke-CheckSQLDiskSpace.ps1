function Invoke-CheckSQLDiskSpace {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    $server = Get-SqlConnection $targetServer

    $cmd = @"
    SELECT DISTINCT 
         vs.volume_mount_point
        ,vs.logical_volume_name
        ,CONVERT(DECIMAL(18,2), vs.total_bytes/1073741824.0) AS total_size_gb
        ,CONVERT(DECIMAL(18,2), vs.available_bytes/1073741824.0) AS available_size_gb
        ,CONVERT(DECIMAL(18,2), vs.available_bytes * 1. / vs.total_bytes * 100.) AS free_space_pct
    FROM sys.master_files AS f WITH (NOLOCK)
    CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.[file_id]) AS vs 
    ORDER BY vs.volume_mount_point OPTION (RECOMPILE);
"@

    #Get disk space and store it in the repository
    try {
        $results = $server.ExecuteWithResults($cmd)
    }
    catch {
        Get-Error $_ -ContinueAfterError
    }

    #Display the results to the console
    if ($results.Tables[0] | Where-Object {$_.free_space_pct -lt 5.0 -and $_.available_size_gb -lt 10.0}) {
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
    }
    elseif ($results.Tables[0] | Where-Object {$_.free_space_pct -lt 20.0 -and $_.free_space_pct -gt 5.0}) {
        Write-Host "`nWARNING:" -BackgroundColor Yellow -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
    }
    else { Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)" }

    $results.Tables[0] | Where-Object {$_.free_space_pct -lt 20.0} | Select-Object volume_mount_point,logical_volume_name,total_size_gb,available_size_gb,free_space_pct | Format-Table -AutoSize
} #Get-DiskSpace