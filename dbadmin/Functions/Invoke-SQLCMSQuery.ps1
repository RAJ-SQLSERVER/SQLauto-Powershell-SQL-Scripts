Function Invoke-SQLCMSQuery {
  <#
  .SYNOPSIS
  Restore SQL Database
  .DESCRIPTION
  The function will retrieve all .sqb files from a location and then iterate through them
  Restoring them to the specified instance. This function will create any folder structures
  required but is dependant on drives being the same.

  The intended use of the function is to restore all databases in a disaster recovery situation.
  .EXAMPLE
  CMSQuery "d:\mybackups" "mysqlinstance"

  #>
  [CmdletBinding()]
  param
  (
    [Parameter( Mandatory=$True,HelpMessage='Specify the name of the Central Management Server?')]
    [string]$CentralManagementServer,
    [Parameter(Mandatory=$True,HelpMessage='Specify a group name in the CMS?')]
    [string]$Group,
    [Parameter(Mandatory=$True,HelpMessage='Sepcify a query to run')]
    [string]$Query
  )

  begin {
    write-verbose "Preparing to run queries"

  }

  Process {
    #Get a list
    #Get a list
    [String]$CMS = $CentralManagementServer
    [String]$CMSGroup = $group
    [String]$SQLQuery = $Query

    #uncomment if not being loaded by dbadmin modules
    #[void][Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO")
 
 
   [psobject]$servers = Get-SQLCMSInstance -CentralManagementServer $CentralManagementServer  | Where-Object {$_.Group -eq $CMSGroup} 

    $dt = New-Object System.Data.DataTable  


    foreach($server in $servers.Instance) {
        $Connection = New-Object System.Data.SQLClient.SQLConnection 
        $Command = New-Object System.Data.SQLClient.SQLCommand 
        $Connection.ConnectionString = "server='$Server';trusted_connection=true;" 
        $Connection.Open() 
        $Command.Connection = $Connection 
        $Command.CommandText = $SQLQuery 
        $Reader = $Command.ExecuteReader() 
        $dt.Load($Reader) 
        $Connection.Close()     
    }

    $dt
    }
}
