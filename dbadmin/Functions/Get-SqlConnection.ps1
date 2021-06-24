function Get-SqlConnection {
  <#
      .SYNOPSIS
      Gets a ServerConnection.
      .DESCRIPTION
      The Get-SqlConnection function  gets a ServerConnection to the specified SQL Server.
      .INPUTS
      None
      You cannot pipe objects to Get-SqlConnection 
      .OUTPUTS
      Microsoft.SqlServer.Management.Common.ServerConnection
      Get-SqlConnection returns a Microsoft.SqlServer.Management.Common.ServerConnection object.
      .EXAMPLE
      Get-SqlConnection "Z002\sql2K8"
      This command gets a ServerConnection to SQL Server Z002\SQL2K8.
      .EXAMPLE
      Get-SqlConnection "Z002\sql2K8" "sa" "Passw0rd"
      This command gets a ServerConnection to SQL Server Z002\SQL2K8 using SQL authentication.
      .LINK
      Get-SqlConnection 
  #>
  param(
    [CmdletBinding()]
    [Parameter(Mandatory=$true)] [string]$sqlserver,
    [string]$username, 
    [string]$password,
    [Parameter(Mandatory=$false)] [string]$applicationName='Morning Health Checks'
  )

  Write-Verbose "Get-SqlConnection $sqlserver"
    
    if($Username -and $Password){
        try { $con = new-object ('Microsoft.SqlServer.Management.Common.ServerConnection') $sqlserver,$username,$password }
        catch { Get-Error $_ }
    }
    else {
        try { $con = new-object ('Microsoft.SqlServer.Management.Common.ServerConnection') $sqlserver }
        catch { Get-Error $_ }
    }
	
  $con.ApplicationName = $applicationName
  try {
    $con.Connect()
  }
  catch {
    Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $targetServer`n"
    Get-Error $_ -ContinueAfterError
  }

  Write-Output $con
    
} #Get-ServerConnection