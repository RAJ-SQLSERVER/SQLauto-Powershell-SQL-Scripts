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
    [string]$CentralManagementServer
  )

  begin {
    write-verbose "Preparing to run queries"
    Try {
    $sqlconnection = New-Object “Microsoft.SqlServer.Management.Common.ServerConnection" SQLMONITOR02
    $sqlconnection.connect()
    }
    Catch {
        Write-Error "Error: Could not connect to Central Management Server $CentralManagementServer"
    }

  }

  Process {
        $collection = @(); $newcollection = @()
 
        try { $cmstore = new-object Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore($sqlconnection)}
        catch { throw "Cannot access Central Management Server" }
 
        Function Parse-ServerGroup($serverGroup,$collection) {
 
            foreach ($instance in $serverGroup.RegisteredServers) {
                $urn = $serverGroup.urn
                $group = $serverGroup.name
                $fullgroupname = $null
 
                for ($i = 0; $i -lt $urn.XPathExpression.Length; $i++) {
                    $groupname = $urn.XPathExpression[$i].GetAttributeFromFilter("Name")

                    if ($groupname -eq "DatabaseEngineServerGroup") { $groupname = $null }

                    if ($i -ne 0 -and $groupname -ne "DatabaseEngineServerGroup" -and $groupname.length -gt 0 ) {
                        $fullgroupname += "$groupname\"
                    }
                }
 
                if ($fullgroupname.length -gt 0) { $fullgroupname = $fullgroupname.TrimEnd("\") }

                $object = New-Object PSObject -Property @{
                        Server = $instance.servername
                        Group = $groupname
                        FullGroupPath = $fullgroupname
                        }
                $collection += $object
            }
 
            foreach($group in $serverGroup.ServerGroups)
            {
                $newobject = (Parse-ServerGroup -serverGroup $group -collection $newcollection)
                $collection += $newobject     
            }
            return $collection
        }
 
        foreach ($serverGroup in $cmstore.DatabaseEngineServerGroup) {  
            
        $servers = Parse-ServerGroup -serverGroup $serverGroup -collection $newcollection 
        foreach ($server in $servers) {
                    [pscustomobject]@{
                        Instance = $server.Server; 
                        Group = $server.Group;
                        FullGroupPath = $server.FullGroupPath;
                    }
        }
            
        }

    }
}
