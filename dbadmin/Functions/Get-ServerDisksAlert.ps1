function Get-ServerDisksAlert {
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
	[Alias("ServerInstance", "SqlServer")]
    [string[]]$ComputerName = $env:COMPUTERNAME,
    [int]$high,
    [int]$medium,
    [int]$low
  )

  process {
    $WarningLevel = @{Name="WarningLevel";Expression={
                    switch($_.FreeSpaceMB) { 
                        {$_ -le $high} {"High";break;} 
                        {$_ -le $medium} {"Medium";break;} 
                        {$_ -le $low} {"Low";break;} 
                        default {"Normal"} 
                        } 
                    }}
    $data = @{Name="Data";Expression={ $_ | ConvertTo-Json}}
    $alertDateTime = @{Name="DateTime";Expression={(Get-Date).ToString()}}
    $alertType = @{Name="AlertType";Expression={"DiskSpace"}}
    $ComputerName | Get-ServerDisks | Where-Object {$_.Label -notin ("System Reserved","Recovery","swap")} | Select $alertDateTime, ComputerName, $AlertType , $WarningLevel , $data
  }
  
}