function Set-SQLDefaultFileGroup {
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
    [Parameter(Mandatory=$True)][string]$filegroup
  )

  begin {
    
    #uncomment if not loading from dbadmin
    #write-verbose "Creating Datatable and loading SMO"
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
    $sql = @"
IF NOT EXISTS (SELECT name FROM $database.sys.filegroups WHERE is_default=1 AND name = N'$filegroup') 
BEGIN 
    ALTER DATABASE [$database] MODIFY FILEGROUP [$filegroup] DEFAULT 
END;
"@

  } #End on Begin

  process {

        write-verbose "Beginning process loop"

        $server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $instance
        $Connection = New-Object System.Data.SQLClient.SQLConnection
        $Connection.ConnectionString = $server.ConnectionContext
        write-verbose $server.name

        Try {
            $Connection.Open()
            $Command = New-Object System.Data.SQLClient.SQLCommand 
            $Command.connection = $Connection
            $command.commandtext = $sql
            $command.ExecuteNonQuery()
        }
        Catch {
            Write-Error $Global:Error[0]
        }
        finally {

            if ($Connection.State -eq "Open") 
            { 
                write-Verbose "Closing Connection..." 
                $Connection.Close() 
            }
        
        }
        
    } # End of Process

}