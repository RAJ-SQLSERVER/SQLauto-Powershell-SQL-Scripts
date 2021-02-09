Function Get-SQLCMSInstance {
  <#
  .SYNOPSIS
  Describe the function here
  .DESCRIPTION
  Describe the function in more detail
  .NOTES
  Tags: DisasterRecovery, Backup, Restore
  Original Author: Ian Pain  
  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
  You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
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
    [Parameter( Mandatory=$True,HelpMessage='Specify the name of the Central Management Server?')]
    [string]$CentralManagementServer,
    [switch]$IncludeCMSServer = $false
  )

  begin {
    write-verbose "Preparing to run queries"

    try {
        $sqlconnection = New-Object "Microsoft.SqlServer.Management.Common.ServerConnection" $CentralManagementServer
        $sqlconnection.connect()
    }
    catch {
        Write-Error "Error: Could not connect to Central Management Server $CentralManagementServer"
    }

  }

  Process {
        $collection = @(); $newcollection = @()
 
        try { 
            $cmstore = new-object Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore($sqlconnection)
        }
        catch { 
            throw "Cannot access Central Management Server" 
        }
 
        foreach ($serverGroup in $cmstore.DatabaseEngineServerGroup) {  
            
            $servers = Expand-CmsServerGroup -serverGroup $serverGroup -collection $newcollection 
            foreach ($server in $servers) {
                        [pscustomobject]@{
                            Instance = $server.Server; 
                            Group = $server.Group;
                            FullGroupPath = $server.FullGroupPath;
                        }
            }
            if($IncludeCMSServer){
                        [pscustomobject]@{
                            Instance = $CentralManagementServer; 
                            Group = "CMS";
                            FullGroupPath = "All Servers\CMS";
                        }
            }
        }

    }
}