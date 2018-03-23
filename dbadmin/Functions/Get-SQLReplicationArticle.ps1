function Get-SQLReplicationArticle {
  <#
  .SYNOPSIS
  Functions adds a new article to an existing replication publisher
  .DESCRIPTION
  Describe the function in more detail
  .EXAMPLE
  Add-SQLReplicationArticle -sqlinstance "myserver" -SourceDatabase
  .PARAMETER sqlinstance
  The computer name to query. Just one.
  .PARAMETER logname
  The name of a file to write failed computer names to. Defaults to errors.txt.
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True, HelpMessage='What is the sql instance where the publication is?')]
    [String]$sqlinstance,
    [Parameter(Mandatory=$False, HelpMessage='What is the source database name?')]        
    [String]$Database,
    [Parameter(Mandatory=$False, HelpMessage='What is the name of the existing publication?')]
    [String]$Publication,
    [Parameter(Mandatory=$False, HelpMessage='What is the name of the existing article?')]
    [String]$Article
  )

  begin {
    #Reference RMO Assembly
    #Run on SQLMONITOR02 as the assemblies are installed on that server.
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Replication") | out-null
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Rmo") | out-null
  }

  process {

    #Configure a default display set
    $defaultDisplaySet = 'DatabaseName','PublicationName','ArticleId','Name','DestinationObjectName','DestinationObjectOwner','Type','PreCreationMethod'

    if ($Article) { [object]$Article = Split-SQLObjectName $Article }

    #Create the default property display set
    $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet(‘DefaultDisplayPropertySet’,[string[]]$defaultDisplaySet)
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

    $repsvr = New-Object "Microsoft.SqlServer.Replication.ReplicationServer" $sqlinstance
    $repDB = %{ if ($Database) {$repsvr.ReplicationDatabases | Where {$Database -contains $_.Name}} else {$repsvr.ReplicationDatabases} }
    $repPub = %{ if ($Publication) {$repDB.TransPublications| Where {$Publication -contains $_.Name}} else {$repDB.TransPublications} }
    $Articles =  %{ if ($Article) {$repPub.TransArticles| Where {$_.SourceObjectName -eq $Article.ObjectName -and $_.SourceObjectOwner -eq $Article.ObjectSchema}} else {$repPub.TransArticles} } 

    #Give this object a unique typename
    $Articles.PSObject.TypeNames.Insert(0,'Replication.Articles')
    $Articles | Add-Member MemberSet PSStandardMembers $PSStandardMembers 

    #Show object that shows only what I specified by default
    Return $Articles
  }
}
