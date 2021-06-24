function Test-ServiceStatus {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    $cmd = "SELECT servicename,CASE SERVERPROPERTY('IsClustered') WHEN 0 THEN startup_type_desc WHEN 1 THEN 'Automatic' END AS startup_type_desc,status_desc FROM sys.dm_server_services;"

    #Get status of each SQL service
    $server = Get-SqlConnection $targetServer
    try {
        $results = $server.ExecuteWithResults($cmd)
    }
    catch {
        Get-Error $_ -ContinueAfterError
    }

    #Display the results to the console
    if ($results.Tables[0] | Where-Object {$_.status_desc -ne 'Running' -and $_.startup_type_desc -eq 'Automatic'}) {
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
    }
    else { Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)" }

    #Display the results to the console
    if ($results.Tables[0] | Where-Object {$_.status_desc -ne 'Running' -and $_.startup_type_desc -eq 'Automatic'}) {
        $results.Tables[0] | ForEach-Object {
            Write-Host "$($_.servicename): $($_.status_desc)"
        }
    }
} #Get-ServiceStatus