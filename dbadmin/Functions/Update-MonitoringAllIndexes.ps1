function Update-MonitoringAllIndexes {
  <#
  .SYNOPSIS
  Describe the function here
  .DESCRIPTION
  Describe the function in more detail
  .EXAMPLE
  Give an example of how to use it
  .EXAMPLE
  Give another example of how to use it
  .PARAMETER computername
  The computer name to query. Just one.
  .PARAMETER logname
  The name of a file to write failed computer names to. Defaults to errors.txt.
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True,HelpMessage='What computer name would you like to target?')]
    [string]$Target,
    [Parameter(Mandatory=$True,HelpMessage='What database name would you like to target?')]
    [string]$TargetDatabase,
    [Parameter(Mandatory=$False,HelpMessage='Would you like to truncate the data first?')]
    [Switch]$Truncate
  )

  begin {
        Write-Verbose "Executing $($MyInvocation.MyCommand)"

        #Check if dependant modules are loaded
        Try {Get-Command -Name Get-SQLIndex -Module dbadmin | Out-Null} Catch { Write-Warning "This function depends on Get-SQLIndex from the dbadmin module" ; Break }
        Try {Get-Command -Name ConvertTo-DataTable -Module dbadmin | Out-Null} Catch { Write-Warning "This function depends on ConvertTo-DataTable from the dbadmin module" ; Break }
  }

  process {

        #Get index information
        $data = Get-SQLIndex -instance $Target | Select DatabaseID, ObjectID, DatabaseName, SchemaName, TableName, IndexID, IndexName

        #Convert it to a format ready to be copied into SQL
        $dt = ConvertTo-DataTable $data

        $cn = new-object System.Data.SqlClient.SqlConnection("Data Source=$Target;Integrated Security=SSPI;Initial Catalog=$TargetDatabase");
        $cn.Open()
        If($truncate) {
            $command = new-object System.Data.SqlClient.SqlCommand ("TRUNCATE TABLE [$TargetDatabase].[dbo].[tblAllIndexes]", $cn)
            $command.ExecuteNonQuery() | Out-Null;
        }
        $bc = new-object ("System.Data.SqlClient.SqlBulkCopy") $cn
        $bc.DestinationTableName = "tblAllIndexes"
        $bc.WriteToServer($dt)


  }

  End {
    $cn.Close()
    $dt.clear()
  }
}
