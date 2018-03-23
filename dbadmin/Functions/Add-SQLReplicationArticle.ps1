function Add-SQLReplicationArticle {
  <#
  .SYNOPSIS
  Functions adds a new article to an existing replication publisher
  .DESCRIPTION
  Describe the function in more detail
  .NOTES
  Tags: Replication
  Original Author: Ian Pain  
  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
  You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
  .EXAMPLE
  Add-SQLReplicationArticle -sqlinstance "mysqlserver" -publicationDbName "mydatabase" -publicationName "mypublication" -ArticleTable "dbo.mytable"
  .EXAMPLE
  Add-SQLReplicationArticle -sqlinstance "mysqlserver" -publicationDbName "mydatabase" -publicationName "mypublication" -ArticleTable "dbo.mytable" -DestinationSchema "MySchema"
  .PARAMETER sqlinstance
  The computer name to query. Just one.
  .PARAMETER publicationDbName
  The name of the database the publication in linked to. Just one.
  .PARAMETER publicationName
  The name of the publication to which you wish to add an article to.
  .PARAMETER ArticleTable
  The name of the tables you wish to add to the publication, if not schema qualified will assume dbo. Can be many.
  .PARAMETER DestinationSchema
  The name of the schema to be used when creating the tabe objects on the subscriber.
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True, HelpMessage='What is the sql instance where the publication is?')]
    [String]$sqlinstance,
    [Parameter(Mandatory=$True, HelpMessage='What is the source database name?')]        
    [String]$publicationDbName ,
    [Parameter(Mandatory=$True, HelpMessage='What is the name of the existing publication?')]
    [String]$publicationName,
    [Parameter(Mandatory=$True, HelpMessage='What table would you like to add to the publication (article)?')]
    [object[]]$ArticleTable,
    [Parameter(Mandatory=$False, HelpMessage='List the columns to be added to the column, all columns will be added if none are specified')]
    [String[]]$ArticleColumns, 
    [Parameter(Mandatory=$False, HelpMessage='What is the schema of the destination table?')]
    [String]$DestinationSchema,
    [Parameter(Mandatory=$False, HelpMessage='Please specify the filter based on this article?')]
    [String]$FilterClause  

  )

  begin {
    #Reference RMO Assembly
    #Run on SQLMONITOR02 as the assemblies are installed on that server.
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Replication") | out-null
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Rmo") | out-null

    Try {
        $publisherConn = New-Object “Microsoft.SqlServer.Management.Common.ServerConnection” $sqlinstance
        $publisherConn.connect()
    }
    Catch {
        Write-Error "Error: Could not connect to Publisher $publisherInstance"
    }
  }

  process {

    $publication = New-Object "Microsoft.SqlServer.Replication.TransPublication" ($publicationName, $publicationDbName,$publisherConn.SqlConnectionObject)

    If ($publication.IsExistingObject) {

        foreach ($table in $ArticleTable) {

            $object = Split-SQLObjectName $table

            $article = $publication.TransArticles | Where {$_.SourceObjectName -match $object.ObjectName -and $_.SourceObjectOwner -eq $object.ObjectSchema}

            if ($article -eq $null) {
                $newArticle = New-Object Microsoft.SqlServer.Replication.TransArticle
                $newArticle.ConnectionContext = $publisherConn.SqlConnectionObject
                $newArticle.Name = "$($object.ObjectName)_$($object.ObjectSchema)"
                $newArticle.DatabaseName = $publicationDbName
                $newArticle.SourceObjectName = $object.ObjectName
                $newArticle.SourceObjectOwner = $object.ObjectSchema
                $newArticle.PublicationName = $publicationName
                $newArticle.DestinationObjectName = $object.ObjectName
                $newArticle.DestinationObjectOwner = %{ If($DestinationSchema) {$DestinationSchema} Else {$object.ObjectSchema} }
                $newArticle.CommandFormat = "IncludeInsertColumnNames, BinaryParameters"
                $newArticle.SchemaOption = "PrimaryObject, CustomProcedures, Identity, KeepTimestamp, ClusteredIndexes, DriPrimaryKey, Collation, DriUniqueKeys, MarkReplicatedCheckConstraintsAsNotForReplication,MarkReplicatedForeignKeyConstraintsAsNotForReplication, Schema"
                $newArticle.Type = "LogBased"
                $newArticle.FilterClause = %{ If($FilterClause) {$FilterClause} Else {""} }
                if($ArticleColumns) {$newArticle.AddReplicatedColumns($ArticleColumns)}
                $newArticle.Create()
            } Else {
                Write-Warning "$($object.ObjectSchema).$($object.ObjectName) already exists in $publicationName publication"
                Continue;
            }
        }
    } 
    else {
        Write-Warning "$publicationName publication does not exists on $publicationDbName"
    }

  }

  End {
        $publisherConn.Disconnect()
  }
}
