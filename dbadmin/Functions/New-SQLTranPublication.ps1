function New-SQLTranPublication {
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
    [Parameter(Mandatory=$True, HelpMessage='What is the name of the publisher SQL instance?')]
    [String]$publisherInstance,
    [Parameter(Mandatory=$True, HelpMessage='What is the name of the publication you want to create?')]
    [String]$publicationName,
    [Parameter(Mandatory=$True, HelpMessage='What is the database you wish to create a publication for?')]
    [String]$publicationDbName
  )

  begin {
    write-verbose "Loading assemblies"
    #Reference Replication Assembly
    #Run on SQLMONITOR02 as the assemblies are installed on that server.
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Replication") | out-null
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Rmo") | out-null
  }

  process {

    Write-Verbose "Making a connection to $publisherInstance"

    Try {
        $publisherConn = New-Object “Microsoft.SqlServer.Management.Common.ServerConnection” $publisherInstance
        $publisherConn.connect()   
        Write-Verbose "Successfully connected to $publisherInstance"
    }
    Catch {
        Write-Error "Error: Could not connect to Publisher $publisherInstance"
    }

    Write-Verbose "Checking to see if Distributor components have been installed"

    Try {
        $distributor = New-Object Microsoft.SqlServer.Replication.ReplicationServer $publisherConn.SqlConnectionObject
        }
    Catch {
        Write-Error "Error: Unable to check Distributer"
    }

    If ( -Not $distributor.DistributorInstalled) {
        Try {
            Write-Verbose "Installed Distributor and Publisher database components"
            
            #Install the distributor components
            $dist_db= New-Object “Microsoft.SqlServer.Replication.DistributionDatabase” “distribution”,$publisherConn
            $distributor.InstallDistributor($publisherConn, $dist_db)

            #Setup and create the publisher components, must do this before creating a publication
            $publisher = New-object “Microsoft.SqlServer.Replication.DistributionPublisher” ($publisherInstance, $publisherConn)
            $publisher.WorkingDirectory = "\\mearsgroup.co.uk\mearsdfs\apps\ferndown\interface\Replication\unc"
            $publisher.DistributionDatabase = "Distribution"
            $publisher.PublisherSecurity.WindowsAuthentication = 1
            $publisher.Create()
        
            Write-Verbose "Finished creating Distributor and Publisher database components"
        }
        Catch {
            Write-Error "Error: Failed to install Distributor"
            Break
        }

    }

    Try {
        Write-Verbose "Starting to create the publication $publicationName on $publisherInstance"

        # Create connections to the Publisher.
        $publicationDB = New-Object "Microsoft.SqlServer.Replication.ReplicationDatabase" ($publicationDbName, $publisherConn.SqlConnectionObject)

        If($publicationDB.LoadProperties()) {

            If ( -not $publicationDB.EnabledTransPublishing) {
                Write-Verbose "Enabling transactional publication for $publicationDbName on $publisherInstance"
                $publicationDB.EnabledTransPublishing = 1
            }

            If ( -not $publicationDB.LogReaderAgentExists) {
                Write-Verbose "Creating Log Reader Agent for $publicationDbName on $publisherInstance"
                $publicationDB.LogReaderAgentPublisherSecurity.WindowsAuthentication = 1
                $publicationDB.CreateLogReaderAgent()
            }

            Write-Verbose "Creating publication $publicationName for $publicationDBName database"
            $publication = New-Object "Microsoft.SqlServer.Replication.TransPublication" ($publicationName, $publicationDbName,$publisherConn.SqlConnectionObject)
            If ( -not $publication.IsExistingObject) {
                $publication.Name = $publicationName
                $publication.ConnectionContext = $publisherConn.SqlConnectionObject
                $publication.DatabaseName = $publicationDbName
                $publication.Description = "Transactional publication of database $publicationDBName from Publisher $publisherInstance created with powershell."
                $publication.SnapshotMethod = [Microsoft.SqlServer.Replication.InitialSyncType]::ConcurrentNative

                $publication.Attributes = $publication.Attributes -bor [Microsoft.SqlServer.Replication.PublicationAttributes] "AllowPull,AllowPush,IndependentAgent"          

                $publication.SnapshotGenerationAgentPublisherSecurity.WindowsAuthentication = 1
                $publication.CreateSnapshotAgentByDefault = 1
                $publication.Status = [Microsoft.SqlServer.Replication.State]::Active

                $publication.Create()
            }
            else {
                Write-Warning "$publicationName publication already exists on $publicationDbName"
            }

            Write-Verbose "Finished creating publication $publicationName for $publicationDBName database"

            return $publication #| Select Name, DatabaseName, Description, Status, Type, HasSubscription, SnapshotMethod

        }
    }
    Catch {
        Write-Error "Error: $($Global:Error[0])"
    }

  }

    End {
        $publisherConn.Disconnect()
    }
}
