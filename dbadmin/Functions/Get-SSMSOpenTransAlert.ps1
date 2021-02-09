function Get-SSMSOpenTransAlert {
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
    [parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
	[Alias("ServerInstance")]
    [string[]]$sqlserver = $env:COMPUTERNAME,
    [int]$high,
    [int]$medium,
    [int]$low
  )

  process {

    Try {
        $Connection = New-Object System.Data.SQLClient.SQLConnection
        $Connection.ConnectionString = "server='$sqlserver';database='master';trusted_connection=true;Application Name=SQL Monitor - Monitoring"
        $Connection.Open()
    }
    Catch {
        Write-Error "Error: Could not connect to $sqlserver"
    }

    if($connection.ServerVersion -lt 12) {
        write-warning "Not compatible with check, must be SQL 2014 and above" 
        return;
    }

    $WarningLevel = @{Name="WarningLevel";Expression={
                    switch($Datatable.rows.Count) {
                        {$_ -eq 0} {"Normal"; break;} 
                        {$_ -ge $high -and $high -ne 0} {"High";break;} 
                        {$_ -ge $medium -and $medium -ne 0} {"Medium";break;} 
                        {$_ -ge $low -and $low -ne 0} {"Low";break;} 
                        default {"Normal"} 
                        } 
                    }}
    $data = @{Name="Data";Expression={ $_ | ConvertTo-Json}}
    $alertDateTime = @{Name="DateTime";Expression={(Get-Date).ToString()}}
    $alertType = @{Name="AlertType";Expression={"SSMSOpenTran"}}
    $sqlInstance = @{Name="SQLInstance";Expression={$sqlserver}}

    [String]$SQLQuery = @"
SELECT 
	tst.session_id,
	host_name, 
	original_login_name, 
	login_name, 
	des.last_request_start_time,
	 last_request_end_time,
	tst.open_transaction_count,
	text
FROM sys.dm_tran_session_transactions tst (READUNCOMMITTED)
INNER JOIN sys.dm_exec_connections ec (READUNCOMMITTED) 
	ON tst.session_id = ec.session_id
INNER Join Sys.DM_Exec_Sessions DES (READUNCOMMITTED) 
	On DES.Session_ID = tst.Session_ID
LEFT JOIN Sys.DM_Exec_Requests DER (READUNCOMMITTED) 
	On DER.Session_ID = DES.Session_ID
CROSS APPLY sys.dm_exec_sql_text(ec.most_recent_sql_handle) st
WHERE 
	Des.[program_name] LIKE 'Microsoft SQL Server Management Studio%' 
	AND DER.session_id IS NULL
	AND DATEDIFF(SECOND,Coalesce(DER.Start_Time,DES.Last_Request_Start_Time),GETDATE()) > 30
"@
    $Datatable = New-Object System.Data.DataTable

    $Command = New-Object System.Data.SQLClient.SQLCommand
    $Command.Connection = $Connection
    $Command.CommandText = $SQLQuery
    $Reader = $Command.ExecuteReader()
    $Datatable.Load($Reader)
    $Connection.Close()

    $results = $Datatable | foreach {
      New-Object -TypeName PSObject -Property @{
        "session_id"  = [System.Int16]        $_.session_id
        "host_name"   = [System.String] $_.host_name
        "original_login_name" = [System.String]        $_.original_login_name
        "last_request_start_time"      = [System.String]        $_.last_request_start_time
        "last_request_end_time"      = [System.String]        $_.last_request_end_time
        "open_transaction_count"      = [System.String]        $_.open_transaction_count
        "text"      = [System.String]        $_.text
      }
    }

    $results | Select $alertDateTime, $sqlInstance, $AlertType , $WarningLevel , $data

  }
 
}

