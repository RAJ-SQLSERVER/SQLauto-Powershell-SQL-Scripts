function Copy-SQLTable {

    Param($sourceInstance,$sourcedb,$TargetInstance,$Targetdb,[String[]]$tableNames,[Switch]$overwrite=$false,$Append)

    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null

    $source = new-object ('Microsoft.SqlServer.Management.Smo.Server') $sourceInstance
    $destination  = new-object ('Microsoft.SqlServer.Management.Smo.Server') $TargetInstance

    $db = $destination.Databases[$Targetdb]

    foreach($tableName in $tableNames) {

        $exists = $false

        $tableObject = Split-SQLObjectName $tableName

        $obj = $source.Databases[$sourcedb].Tables[$tableObject.ObjectName,$tableObject.ObjectSchema]

        $destTable = "$($tableObject.ObjectName)$append"
        $destSchema = $tableObject.ObjectSchema

        if(-not $db.Schemas[$destSchema]) {
            $schema = new-object Microsoft.SqlServer.Management.Smo.Schema($db,$destSchema)
            $schema.Create()
        }

        if(-not $db.Tables.Contains($destTable,$destSchema)) {

            $table = new-object Microsoft.SqlServer.Management.Smo.Table($db,$destTable,$destSchema)
            $table.AnsiNullsStatus = $obj.AnsiNullsStatus
            $table.QuotedIdentifierStatus = $obj.QuotedIdentifierStatus
            $table.TextFileGroup = $obj.TextFileGroup
            $table.FileGroup = $obj.FileGroup
    
            foreach ($column in $obj.Columns) {
    
                $col = New-Object Microsoft.SqlServer.Management.Smo.Column($table,$column.name, $column.DataType)
                $col.Collation = $column.Collation
                $col.Nullable = $column.Nullable
                $col.Default = $column.Default
    
                $col.IsPersisted = $column.IsPersisted
                $col.DefaultSchema = $column.DefaultSchema
                $col.RowGuidCol = $column.RowGuidCol
    
                if($source.VersionMajor -ge 10) {
                    $col.IsFileStream = $column.IsFileStream
                    $col.IsSparse = $column.IsSparse
                    $col.IsColumnSet = $column.IsColumnSet
                }
    
                $table.Columns.Add($col)
    
            }
    
            $table.Create()

            foreach($index in $obj.Indexes) {

                if($index.IsClustered) {

                    $copyindex = New-Object Microsoft.SqlServer.Management.Smo.Index -ArgumentList $table, $index.name
                    $copyindex.IndexType = $index.IndexType

                    foreach($indexcol in $index.IndexedColumns) {
                        $col = New-Object Microsoft.SqlServer.Management.Smo.IndexedColumn
                        $col.Name = $indexcol.Name
                        $col.Parent = $copyindex
                        $col.Descending = $indexcol.Descending
                        $col.IsIncluded = $indexcol.IsIncluded
                        $copyindex.IndexedColumns.Add($col)
                    }
                    $copyindex.IsClustered = $index.IsClustered
                    $copyindex.FillFactor = $index.FillFactor
                    $copyindex.FilterDefinition = $index.FilterDefinition
                    $copyindex.IndexKeyType = $index.IndexKeyType 
                                        $copyindex.IndexKeyType = $index.IndexKeyType
                    Try {
                        $copyindex.Create()
                        $copyindex.DisallowPageLocks = $true
                        $copyindex.Alter()
                    }
                    Catch {
                        $error[0].Exception
                    }
                  
                }

            }
        }
        else {
            $exists = $true
            Write-Warning "$($destSchema).$($destTable) exists in destination, overwrite flag set to $overwrite"
        }
        if($exists -eq $false -or ($exists -and $overwrite)) {
            Try {
            
                $SrcConn  = new-object System.Data.SqlClient.SqlConnection("Data Source=$($source.Name);Integrated Security=SSPI;Initial Catalog=$sourcedb")
                $TargetConn  = new-object System.Data.SqlClient.SqlConnection("Data Source=$($destination.Name);Integrated Security=SSPI;Initial Catalog=$TargetDB")
                $SrcConn.Open()
                $TargetConn.Open()
                [regex]$pattern1 = "\."
                [regex]$pattern2 = "[[\]]"
                $tableName = $pattern1.replace("[$($pattern2.replace($tableName,''))]","].[",1)
                if($overwrite) {
                    $TCmd = New-Object system.Data.SqlClient.SqlCommand("TRUNCATE TABLE $tableName", $TargetConn)
                    $retValue = $TCmd.ExecuteNonQuery()
                }
                $CmdText = "SELECT * FROM " + $tableName
                Write-Host $CmdText
                $SqlCommand = New-Object system.Data.SqlClient.SqlCommand($CmdText, $SrcConn) 
                $sqlCommand.CommandTimeout = 0
                $bulkCopyOptions =  [System.Data.SqlClient.SqlBulkCopyOptions]::TableLock
                [System.Data.SqlClient.SqlDataReader] $SqlReader = $SqlCommand.ExecuteReader()
                $bulkCopy = New-Object Data.SqlClient.SqlBulkCopy("Data Source=$($destination.Name);Integrated Security=SSPI;Initial Catalog=$TargetDB", $bulkCopyOptions)
                $destTableName = $pattern1.replace("[$($pattern2.replace("$($destSchema).$($destTable)",''))]","].[",1)
                $bulkCopy.DestinationTableName = $destTableName
                $bulkCopy.BulkCopyTimeout = 0
                $bulkcopy.EnableStreaming = $true
                $bulkCopy.WriteToServer($sqlReader)


            }

            Catch [System.Exception]    {
                $ex = $_.Exception
                Write-Host $ex.Message
            }

            Finally {
                $SqlReader.close()
                $SrcConn.Close()
                $SrcConn.Dispose()
                $TargetConn.Close()
                $TargetConn.Dispose()
            }
        }
        Else {
            Write-Warning "Skipping copying data for $tableName as overwrite switch not set to True"
        }

    }

}
