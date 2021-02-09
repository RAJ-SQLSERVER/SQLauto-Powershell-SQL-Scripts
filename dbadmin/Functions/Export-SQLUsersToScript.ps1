Function Export-SQLUsersToScript {

	[CmdletBinding()]
	Param (
		[parameter(Mandatory = $true)]
		[object]$sqlinstance,
        [parameter(Mandatory = $true)]
		[string]$database,
        [string[]]$filter = $null
	)

    $srv = New-Object Microsoft.SqlServer.Management.Smo.Server $sqlinstance
    $db = $srv.Databases[$database]

    $list = $db.Users | %{$_.Name} 

    if(!$filter) {
        $filter = Show-CheckList -list $list -Title "SQL Logins" -header "Select login(s) to retain:"
    }

    $users = $db.Users | Where {$_.name -in $filter}

    $ScriptingOptions = New-Object "Microsoft.SqlServer.Management.Smo.ScriptingOptions";
    #$ScriptingOptions.TargetServerVersion = [Microsoft.SqlServer.Management.Smo.SqlServerVersion]::Version90; #Version90, Version100, Version105
    $ScriptingOptions.AllowSystemObjects = $false
    $ScriptingOptions.IncludeDatabaseRoleMemberships = $true
    $scriptingOptions.Permissions = $true

    foreach($user in $users) {      
        $output += $user.script($ScriptingOptions)
             
        #Database Object Permissions
        foreach ($ObjectPermission in $db.EnumObjectPermissions($user.Name) | Where-Object {@("sa","dbo","information_schema","sys") -notcontains $_.Grantee -and $_.Grantee -notlike "##*"})
        {
            switch ($ObjectPermission.ObjectClass)
			{
				"Schema" 
                { 
                    $Object = "SCHEMA::[" + $ObjectPermission.ObjectName + "]" 
                }
					    
                "User" 
                { 
                    $Object = "USER::[" + $ObjectPermission.ObjectName + "]" 
                }
                        
                default 
                { 
                    $Object = "[" + $ObjectPermission.ObjectSchema + "].[" + $ObjectPermission.ObjectName + "]" 
                }
			}

            if ($ObjectPermission.PermissionState -eq "GrantWithGrant")
            {
                $WithGrant = "WITH GRANT OPTION"
                        
            } 
            else 
            {
                $WithGrant = ""
            }
            $GrantObjectPermission = $ObjectPermission.PermissionState.ToString().Replace("WithGrant","").ToUpper()

            $output += "$GrantObjectPermission $($ObjectPermission.PermissionType) ON $Object TO [$($ObjectPermission.Grantee)] $WithGrant"
        }
    }

    Return $output

}