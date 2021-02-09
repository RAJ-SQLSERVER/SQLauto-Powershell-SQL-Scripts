function Get-SQLReplicationPublication {
  <#
  .SYNOPSIS
  Functions finds local publications for specified server
  .DESCRIPTION
  Describe the function in more detail
  .EXAMPLE
  Get-SQLReplicationPublication -sqlinstance "myserver"
  .PARAMETER sqlinstance
  The computer name to query. Just one.
  .PARAMETER Database
  The name of the database to target.
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True, HelpMessage='What is the sql instance where the publication is?')]
    [String]$sqlinstance,
    [Parameter(Mandatory=$False, HelpMessage='What is the source database name?')]        
    [String]$Database
  )

  begin {
    #Reference RMO Assembly
    #Run on SQLMONITOR02 as the assemblies are installed on that server.
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Replication") | out-null
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Rmo") | out-null
  }

  process {

    #Configure a default display set
    $defaultDisplaySet = 'Name','DatabaseName','Description','Status','Type','HasSubscription','TransSubscriptions','AltSnapshotFolder','SnapshotMethod'

    #Create the default property display set
    $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet(‘DefaultDisplayPropertySet’,[string[]]$defaultDisplaySet)
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

    $repsvr = New-Object "Microsoft.SqlServer.Replication.ReplicationServer" $sqlinstance
    $repDB = %{ if ($Database) {$repsvr.ReplicationDatabases | Where {$Database -contains $_.Name}} else {$repsvr.ReplicationDatabases} }
    $repPub = $repDB.TransPublications

    #Give this object a unique typename
    $repPub.PSObject.TypeNames.Insert(0,'Replication.Articles')
    $repPub | Add-Member MemberSet PSStandardMembers $PSStandardMembers 

    #Show object that shows only what I specified by default
    $repPub
  }
}
