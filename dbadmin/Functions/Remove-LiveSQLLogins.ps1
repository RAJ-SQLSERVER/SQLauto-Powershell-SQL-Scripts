Function Remove-LiveSQLLogins {

	[CmdletBinding()]
	Param (
		[parameter(Mandatory = $true)]
		[object]$sqlinstance,
        [parameter(Mandatory = $true)]
		[string]$database,
        [switch]$listonly = $false
	)

    $srv = New-Object Microsoft.SqlServer.Management.Smo.Server $sqlinstance
    $db = $srv.Databases[$database]

    $list = @("MEARSDOM\SQLService|1","Mearsdom\ME2Services|1","mearsdom\MCMWebUser|1","MEARSDOM\MCMSI|1")
    $list += $db.Users | Where {$_.LoginType -eq "WindowsGroup"} | %{$_.Name} 

    $exclude = Show-CheckList -list $list -Title "SQL Logins" -header "Select login(s) to retain:"

    $users = $db.Users | Where {$_.LoginType -in ("WindowsUser","WindowsGroup") -and $_.name -notin $exclude}

    write-host "Gathering information about users and objects" -ForegroundColor Green

    $schemas = $db.Schemas | Where-Object {$_.owner -in $users.name} 
    $procedures = $db.StoredProcedures  | Where-Object {$_.owner -in $users.name} 
    $queues = $db.ServiceBroker.Queues | Where-Object {$_.schema -in $schemas.name} 
    $services = $db.ServiceBroker.Services | Where-Object {$_.owner -in $schemas.name} 
    $tables  = $db.Tables | Where-Object {$_.schema -in $schemas.name}

    if($listonly) {

        $schemas  | Select @{Name="Type";Expression={"Schema"}}, Name  | ft
        $procedures | Select @{Name="Type";Expression={"StoredProcedure"}}, Name | ft
        $queues | Select @{Name="Type";Expression={"Queue"}}, Name | ft
        $services | Select @{Name="Type";Expression={"Service"}}, Name | ft
        $tables | Select @{Name="Type";Expression={"Table"}}, Name | ft
        $users | Select @{Name="Type";Expression={"User"}}, Name | ft

    }
    else {
        Try {
            $Tables | Show-Progress -Activity "Removing tables..." | Foreach-Object {$_.DropIfExists()}
            $Services | Show-Progress -Activity "Removing service broker services..."  | Foreach-Object {$_.DropIfExists()}
            $Queues | Show-Progress -Activity "Removing service broker queues..."  | Foreach-Object {$_.DropIfExists()}
            $Procedures | Show-Progress -Activity "Removing procedures..."  | Foreach-Object {$_.DropIfExists()}
            $Schemas | Show-Progress -Activity "Removing schemas..."  | Foreach-Object {$_.DropIfExists()}
            $users | Show-Progress -Activity "Removing users..."  | Foreach-Object {$_.DropIfExists()}
        }
        Catch {
            Write-Error "Error: $($_.Exception)"
        }
    }

}

