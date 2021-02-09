function Add-SQLPullSubscription {
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
    [Parameter(Mandatory=$True,HelpMessage='What computer name would you like to target?')]
    [String]$subscriberInstance,
    [String]$subscriptionDbName,
    [String]$publicationName,
    [String]$publisherInstance,
    [String]$publicationDbName
  )

  begin {
        write-verbose "Deleting $logname"
  }

  process {

        write-verbose "Beginning process loop"
        Try {
            $publisherConn = New-Object “Microsoft.SqlServer.Management.Common.ServerConnection” $publisherInstance
            $publisherConn.DatabaseName = $publicationDbName
            $publisherConn.connect()

            $SubscriberConn = New-Object “Microsoft.SqlServer.Management.Common.ServerConnection” $subscriberInstance
            $SubscriberConn.DatabaseName = $subscriptionDbName
            $SubscriberConn.connect()
        }
        Catch {
            Write-Error "Error: Could not connect to Publisher/Subscriber database"
        }

        Try {

            # Create connections to the Publisher and Subscriber.
            $publication = New-Object "Microsoft.SqlServer.Replication.TransPublication" ($publicationName, $publicationDbName,$publisherConn.SqlConnectionObject)

            If($publication.LoadProperties()) {

                If ($publication.Attributes -notmatch "AllowPull") {
                    $publication.Attributes = "AllowPull ,$($publication.Attributes)"
                    $publication.CommitPropertyChanges()
                }
                $SyncType = [Microsoft.SqlServer.Replication.SubscriptionSyncType]::Automatic
                $SubscriberType = [Microsoft.SqlServer.Replication.TransSubscriberType]::ReadOnly
                       
                #$subscriber = New-Object "Microsoft.SqlServer.Replication.TransPullSubscription" ("MearsData_Silo","FERNMCMSQL02","MearsData_HFI","MearsData_HFI_Silo",$SubscriberConn)
                $subscriber = New-Object "Microsoft.SqlServer.Replication.TransPullSubscription"
                $subscriber.ConnectionContext = $subscriberConn.SqlConnectionObject
                $subscriber.DatabaseName = $subscriptionDbName
                $subscriber.Description = "Pull subscription to $publicationDbName on $publisherInstance"
                $subscriber.PublisherName = $publisherInstance
                $subscriber.PublicationName = $publicationName
                $subscriber.PublicationDBName = $publicationDbName

                $subscriber.AgentSchedule.FrequencyType = [Microsoft.SqlServer.Replication.ScheduleFrequencyType]::Continuously

                $subscriber.CreateSyncAgentByDefault = 1

                $subscriber.Create()

                [switch]$registered = $false

                foreach($subscriber in $publication.EnumSubscriptions()) {
                    if($subscriber.SubscriberName -eq $subscriptionDbName) {
                        $registered = $true
                    }
                }

                if(!$registered) {
                    $publication.MakePullSubscriptionWellKnown($subscriberInstance,$subscriptionDbName,$SyncType,$SubscriberType)
                    $publication.CommitPropertyChanges()
                }

                $subscriber | Select PublisherName, PublicationDBName, PublicationName, @{Name = "SubscriberName" ; Expression = { $subscriberInstance } }, @{Name = "SubscriptionDB" ; Expression = { $subscriptionDbName } }

            }
            else {
                Write-warning "$publicationName publication does not exists on $publicationDbName"
            }
        }
        Catch {
            $ErrorMessage = $_.Exception.Message
            Write-Error "Crap something went wrong creating the pull subscription: $ErrorMessage"

        }
    
  }

  End {
        $publisherConn.Disconnect()
        $SubscriberConn.Disconnect()
  }
}
