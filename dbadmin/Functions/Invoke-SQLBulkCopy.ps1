Function Invoke-SQLBulkCopy([Object]$dataTable, [String]$table, [Object]$Connection){

    $cn = new-object System.Data.SqlClient.SqlConnection($connection);
    $cn.Open()

    try 
    { 
        $bulkCopy = new-object ("Data.SqlClient.SqlBulkCopy") $cn 
        $bulkCopy.DestinationTableName = $table 
        $bulkCopy.BatchSize = 500 
        $bulkCopy.BulkCopyTimeout = 30 
        $bulkCopy.WriteToServer($dataTable) 
    } 
    catch 
    { 
        $ex = $_.Exception 
        Write-Error "$ex.Message" 
        continue 
    }
}