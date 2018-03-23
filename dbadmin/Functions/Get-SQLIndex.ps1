function Get-SQLIndex {
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
    [Parameter(Mandatory=$True,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
      HelpMessage='What SQL instance name would you like to target?')]
    [Alias('server ')]
    [ValidateLength(3,30)]
    [string]$instance,
	[string]$database,
    [string]$table,
    [string]$logname = 'errors.txt'
  )

  begin {
    
    #uncomment if not loading from dbadmin
    #write-verbose "Creating Datatable and loading SMO"
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

    if($table) {$Predicate = "Where tbl.name = '$table'"} else {$predicate = $null}

    $IndexQuery = @"
SELECT
DB_NAME() as [DatabaseName], 
DB_ID() as [DatabaseID],
tbl.object_id as [ObjectID],
schema_id as [SchemaID],
SCHEMA_NAME(schema_id) as [SchemaName],
tbl.name as [TableName],
i.index_id as [IndexID],
i.name as [IndexName],
i.type_desc as IndexType,
LEFT(ixc.IndexedColumns, LEN(ixc.IndexedColumns)-1) as [IndexedColumns] ,
LEFT(ic.IncludedColumns, LEN(ic.IncludedColumns)-1) as [IncludedColumns]
FROM
sys.tables AS tbl
INNER JOIN sys.indexes AS i ON (i.index_id > 0 and i.is_hypothetical = 0) AND (i.object_id=tbl.object_id)
OUTER APPLY (
SELECT _c.name + ',' FROM
sys.indexes AS _i
INNER JOIN sys.index_columns _ic ON _ic.object_id = _i.object_id AND _ic.index_id = _i.index_id and _ic.is_included_column = 0
INNER JOIN sys.columns _c ON _c.object_id = _ic.object_id AND _c.column_id = _ic.column_id
WHERE _i.index_id = i.index_id and _c.object_id = tbl.object_id
ORDER BY _c.column_id
FOR XML PATH('')
) ixc(IndexedColumns)
OUTER APPLY (
SELECT _c.name + ',' FROM
sys.indexes AS _i
INNER JOIN sys.index_columns _ic ON _ic.object_id = _i.object_id AND _ic.index_id = _i.index_id and _ic.is_included_column = 1
INNER JOIN sys.columns _c ON _c.object_id = _ic.object_id AND _c.column_id = _ic.column_id
WHERE _i.index_id = i.index_id and _c.object_id = tbl.object_id
ORDER BY _c.column_id
FOR XML PATH('')
) ic(IncludedColumns)
$Predicate
ORDER BY [TableName], [IndexID]
"@

  } #End on Begin

  process {

        write-verbose "Beginning process loop"

        $server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $instance
        write-verbose $server.name

        if ($database -ne "") {
            write-verbose "processing database parameter"
            $dbs = $server.Databases[$database]
        } else {
            write-verbose "No database parameter set processing all databases"
            $dbs = $server.Databases
        }

        if ($dbs) {   
            foreach ($db in $dbs) {
            write-verbose $db.Name
            $IndexDetails = ($db.ExecuteWithResults($IndexQuery)).Tables[0];
            foreach ($detail in $IndexDetails)
				{
                    [pscustomobject]@{
                        Instance = $instance; 
                        DatabaseName = $db.Name;
                        DatabaseID = $detail.DatabaseID; 
                        ObjectID = [Int32]$detail.ObjectID; 
                        SchemaName = $detail.SchemaName; 
                        TableName = $detail.TableName; 
                        IndexID =  $detail.IndexID;
                        IndexName = $detail.IndexName;
                        IndexType = $detail.IndexType; 
                        IndexedColumns =  $detail.IndexedColumns
                        IncludedColumns = $detail.IncludedColumns
                    }
                }

            }
        }
        Else {
            Write-Warning "Could not find a database called $database on $instance"
		    continue
        }
        
    } # End of Process

}