Function Invoke-SQLFixOrphanedUsers {
    [CmdletBinding()]
    Param(
        [String]$sqlInstance = "A34120",
        [String]$Database
    )

    $users = Invoke-Sqlcmd2 -ServerInstance $sqlInstance -Database $Database -Query "exec sp_change_users_login 'report'"

    foreach($user in $users) {
        write-host "exec sp_change_users_login 'auto_fix','$($user.UserName)'"
        Try {
            Invoke-Sqlcmd2 -ServerInstance $sqlInstance -Database $Database -Query "exec sp_change_users_login 'auto_fix','$($user.UserName)';"
        }
        Catch [System.Data.SqlClient.SqlException] {
            Write-Warning $_.ToString()
        }
    }
}