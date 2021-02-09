Function Invoke-SQLSchemaDeploy {
        param (
            [object]$object = $null,
            [string]$object_path = $null,
            [object]$connection = $null
        )
        $extype = [Microsoft.SqlServer.Management.Common.ExecutionTypes]::ContinueOnError

        $myConnection = new-object("Microsoft.SqlServer.Management.Common.ServerConnection")
        $myConnection.ServerInstance = $_connection.ServerInstance
        $myConnection.LoginSecure = $false
        $myConnection.Login = $_connection.Username
        $myConnection.Password = $_connection.Password
        $server = New-Object Microsoft.SQLServer.Management.Smo.Server($myConnection)
        $db = $Server.Databases[$_connection.Database]
        

        if ($_object -ne $null) {
            #
        }
        else {
                $objects = "Tables","Assemblies","Functions","Stored Procedures","Triggers","Views","Schemas","Roles","Users","Security","Synonyms","Indexes"
                
                foreach($object in $objects) {
                    $files = Get-ChildItem -Path $_object_path -Recurse -Include *.sql | Where {$_.DirectoryName -eq "$_object_path\$object"}
                    foreach ($file in $files) {
                        $file.FullName
                        $script = Get-Content -LiteralPath $file.FullName -raw
                        $db.ExecuteNonQuery($script) | Out-Null
                    }
                }
         }
}
