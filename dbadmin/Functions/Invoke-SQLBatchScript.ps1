Function Invoke-SQLBatchScript {
        Param(
        [string]$SQLInstance,
        [string]$Database,
        [string]$Script,
        [string]$file
    )

    if(!$file -and !$script) {
        Write-Error "Please specify a value for one of the variables Script or File"
    }

    if($file) {
        try {
            $Script = Get-Content $file
        }
        catch {
            Write-Error "Error trying to read the contents of $file"
        }
    }


    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$SQLInstance;Database=$Database;Trusted_Connection=True;"
    $SqlConnection.Open()

    $batches = $Script -split "GO\r\n"

    foreach($batch in $batches)
    {
        if ($batch.Trim() -ne ""){

            $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
            $SqlCmd.CommandText = $batch
            $SqlCmd.Connection = $SqlConnection
            $result = $SqlCmd.ExecuteNonQuery()
        }
    }

    $SqlConnection.Close()
}