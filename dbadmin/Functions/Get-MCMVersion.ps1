function Get-MCMVersion {
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
	[string]$database
  )

  begin {
    #Query to get version of currrent MCM database
    [String]$MCMVersionQuery = "SELECT [Version] FROM [dbo].[tblMCMSystem]"

    $server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $instance
    write-verbose $server.name
  }

  process {

        write-verbose "Beginning process loop"

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
                if ($db.Tables["tblMCMSystem"]) {
                    $VersionDetails = ($db.ExecuteWithResults($MCMVersionQuery)).Tables[0];
                    [pscustomobject]@{
                        Instance = $instance; 
                        DatabaseName = $db.Name;
                        MCMVersion = $VersionDetails.Version;
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
