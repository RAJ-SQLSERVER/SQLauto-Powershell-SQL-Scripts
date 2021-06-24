function Invoke-CheckSQLUpTime {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    $server = Get-SqlConnection $targetServer

    #Get startup time
    $cmd = "SELECT sqlserver_start_time FROM sys.dm_os_sys_info;"
    try {
        $sqlStartupTime = $server.ExecuteScalar($cmd)
    }
    catch {
        Get-Error $_ -ContinueAfterError
    }

    $upTime = (New-TimeSpan -Start ($sqlStartupTime) -End (Get-Date))

    #Display the results to the console
    if ($upTime.Days -eq 0 -and $upTime.Hours -le 6) {
        #Critical if uptime is less than 6 hours
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
        Write-Host "Uptime: $($upTime.Days).$($upTime.Hours):$($upTime.Minutes):$($upTime.Seconds)"
    }
    elseif ($upTime.Days -lt 1 -and $upTime.Hours -gt 6) {
        #Warning if uptime less than 1 day but greater than 6 hours
        Write-Host "`nWARNING:" -BackgroundColor Yellow -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
        Write-Host "Uptime: $($upTime.Days).$($upTime.Hours):$($upTime.Minutes):$($upTime.Seconds)"
    }
    else {
        #Good if uptime is greater than 1 day
        Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
        Write-Host "Uptime: $($upTime.Days).$($upTime.Hours):$($upTime.Minutes):$($upTime.Seconds)"
    }
} #Get-SqlUptime