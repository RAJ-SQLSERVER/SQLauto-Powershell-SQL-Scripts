function Invoke-DailyChecks {

    Param ([string[]]$ServerList = $null, [string]$cmsServer = $null, [string]$cmsGroup = $null)

    begin {
        Clear-Host

        #Get the server list from the CMS group, only if one was specified
        if($cmsServer) {
            $targetServerList = Get-CmsServer -cmsServer $cmsServer -cmsGroup $cmsGroup -recurse
        }
        else {
            $targetServerList = $serverList
        }
    }
    
    process {
        $startTime = Get-Date

        #Check uptime of each SQL Server
        Write-Host "`nSQL Server Uptime Check (DD.HH:MM:SS):" -ForegroundColor Green
        ForEach ($targetServer in $targetServerList) { Invoke-CheckSqlUptime -targetServer $targetServer}

        #Get the status of each SQL service
        Write-Host "`nSQL Service(s) Status Check:" -ForegroundColor Green
        ForEach ($targetServer in $targetServerList) { Invoke-CheckServiceStatus -targetServer $targetServer }

        #Get the state of each Windows cluster node
        Write-Host "`nWindows Cluster Node Status Check:" -ForegroundColor Green
        ForEach ($targetServer in $targetServerList) { Invoke-CheckClusterStatus -targetServer $targetServer }

        #Get status of each database for each server
        Write-Host "`nDatabase Status Check:" -ForegroundColor Green
        ForEach ($targetServer in $targetServerList) { Invoke-CheckSQLDBStatus -targetServer $targetServer}

        #Get status of each Availability Group for each server
        Write-Host "`nAvailability Groups Check:" -ForegroundColor Green
        ForEach ($targetServer in $targetServerList) { Invoke-CheckAGStatus -targetServer $targetServer}

        #Get the most recent backup of each database
        Write-Host "`nDatabase Backup Check:" -ForegroundColor Green
        ForEach ($targetServer in $targetServerList) { Invoke-CheckSQLBackupStatus -targetServer $targetServer}

        #Get the disk space info for each server
        Write-Host "`nDisk Space Report:" -ForegroundColor Green
        ForEach ($targetServer in $targetServerList) { Invoke-CheckSQLDiskSpace -targetServer $targetServer}

        #Get the failed jobs for each server
        Write-Host "`nFailed Jobs Report:" -ForegroundColor Green
        ForEach ($targetServer in $targetServerList) { Invoke-CheckFailedSQLJobs -targetServer $targetServer}

        #Check the Application event log for SQL errors
        Write-Host "`nApplication Event Log Report:" -ForegroundColor Green
        #ForEach ($targetServer in $targetServerList) { Invoke-CheckAppLogEvents -targetServer $targetServer}

        Write-Host "`nElapsed Time: $(New-TimeSpan -Start $startTime -End (Get-Date))"

    }

}