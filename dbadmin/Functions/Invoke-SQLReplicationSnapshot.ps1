function Invoke-SQLReplicationSnapshot {
  <#
  .SYNOPSIS
  Functions initiates the replication snapshot agent
  .DESCRIPTION
  Connects to specified instance and starts the replication snapshot for the specified publication for the specified database
  .EXAMPLE
  Invoke-SQLReplicationSnapshot -sqlinstance "MSsqlinstance" -Database "MSsqldatabase" -Publication "MSsqlpublication"
  .PARAMETER sqlinstance
  The computer name to query. Just one.
  .PARAMETER Database
  What is the source database name?
  .PARAMETER Publication
  What is the name of the existing publication?
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True, HelpMessage='What is the sql instance where the publication is?')]
    [String]$sqlinstance,
    [Parameter(Mandatory=$True, HelpMessage='What is the source database name?')]        
    [String]$publicationDbName,
    [Parameter(Mandatory=$True, HelpMessage='What is the name of the existing publication?')]
    [String]$publicationName
  )

  begin {
    #Reference RMO Assembly
    #Run on SQLMONITOR02 as the assemblies are installed on that server.
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Replication") | out-null
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Rmo") | out-null

    Try {
        #$publisherConn = New-Object “Microsoft.SqlServer.Management.Common.ServerConnection” POPEYE01
        $publisherConn = New-Object “Microsoft.SqlServer.Management.Common.ServerConnection” $sqlinstance
        $publisherConn.connect()
    }
    Catch {
        Write-Error "Error: Could not connect to Publisher $publisherInstance"
    }
  }

  process {

    #Add some notes and tests

    #$publication = New-Object "Microsoft.SqlServer.Replication.TransPublication" ('MearsData_Glasgow_Silo', 'MearsData_Glasgow',$publisherConn)
    
    #$publication | gm
    $publication = New-Object "Microsoft.SqlServer.Replication.TransPublication" ($publicationName, $publicationDbName,$publisherConn.SqlConnectionObject)

    #$publicationName = "MearsData_Ben_Silo"
    $Monitor = New-Object "Microsoft.SqlServer.Replication.ReplicationMonitor" ($publisherConn.SqlConnectionObject)
    #Check current status of agent
    $SnapAgent = $Monitor.EnumSnapshotAgents() | foreach { $_.Tables} | foreach { $_.Rows | Where {$_.publication -eq $publicationName} }
    
    If ($publication.IsExistingObject -and  $SnapAgent.status -ne 3 ) {
        $publication.RefreshSubscriptions() 
        $publication.StartSnapshotGenerationAgentJob()   
    }
    else {
        Write-Warning "$publicationName publication does not exists on $publicationDbName"
    }

    $r = [regex] "\[([^\[]*)\%]"

    While ($SnapAgent.status -ne 3 -and $SnapAgent.status -ne 1 ) {
        Start-Sleep -Milliseconds 500
        $SnapAgent = $Monitor.EnumSnapshotAgents() | foreach { $_.Tables} | foreach { $_.Rows | Where {$_.publication -eq $publicationName} }
        #write-host $SnapAgent.status
    }


    While ($SnapAgent.status -eq 3 -or $SnapAgent.status -eq 1) {
        $match = $r.match($SnapAgent.comments)
        $perc = $match.groups[1].value
        Write-Progress -Activity "Running snapshot for $publicationName" -Status $SnapAgent.comments -PercentComplete $perc
        Start-Sleep -Seconds 1
        $SnapAgent = $Monitor.EnumSnapshotAgents() | foreach { $_.Tables} | foreach { $_.Rows | Where {$_.publication -eq $publicationName} }
    }
  }
}


