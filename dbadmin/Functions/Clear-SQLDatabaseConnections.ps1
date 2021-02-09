function Clear-SQLDatabaseConnections {
  <#
  .SYNOPSIS
  To clear connections on a database
  .DESCRIPTION
  This clears all connections on a database by setting the database to single user with rollback and then setting back to multi user
  .NOTES
  Tags: Connections,Clear
  Original Author: Ian Pain  
  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
  You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
  .EXAMPLE
  Clear-SQLDatabaseConnections -sqlinstance "MyServer" -database "MyDatabase"
  .PARAMETER sqlinstance
  The name of the sql instance to clear connections on.
  .PARAMETER database
  The name of the database to clear connection on.
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True)]
    [Alias('instance')]
    [string[]]$sqlinstance,
    [Parameter(Mandatory=$True)]
    [string[]]$database
  )

  process {

    write-verbose "Clearing connections for $database on $sqlinstance"

    Try {
        $srv = New-Object Microsoft.SqlServer.Management.Smo.Server $sqlinstance
        $db = $srv.Databases[$database]
        $db.UserAccess = [Microsoft.SqlServer.Management.Smo.DatabaseUserAccess]::Single;
        $db.Alter([Microsoft.SqlServer.Management.Smo.TerminationClause]::RollbackTransactionsImmediately);
        $db.Refresh();
        $db.UserAccess = [Microsoft.SqlServer.Management.Smo.DatabaseUserAccess]::Multiple;
        $db.Alter();
        $db.Refresh();
    }
    Catch {
        Write-Error "Error: $($_.Exception.Message)"
    }
  }
}

