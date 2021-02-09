Function Invoke-SQLBulkCopy([Object]$dataTable, [String]$table, [Object]$Connection, [switch]$Truncate = $false){

    try 
    {     
        $cn = new-object System.Data.SqlClient.SqlConnection($connection);
        $cn.Open()
        if($Truncate) {
            $command = new-object System.Data.SqlClient.SqlCommand ("TRUNCATE TABLE $table", $cn)
            $command.ExecuteNonQuery();
        }
        $bulkCopy = new-object ("Data.SqlClient.SqlBulkCopy") $cn 
        $bulkCopy.DestinationTableName = $table 
        $bulkCopy.BatchSize = 1000 
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