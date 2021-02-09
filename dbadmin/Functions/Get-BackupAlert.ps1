function Get-BackupAlert {
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
    [Parameter(ParameterSetName = "full")]
    [switch]$LastFull,
    [Parameter(ParameterSetName = "diff")]
    [switch]$LastDiff,
    [Parameter(ParameterSetName = "log")]
    [switch]$LastLog,
    [int]$high,
    [int]$medium,
    [int]$low
  )

  process {
    $WarningLevel = @{Name="WarningLevel";Expression={
                    switch($_.DaysSinceLastBackup) {
                        {$_ -eq 0} {"Normal"; break;} 
                        {$_ -ge $high -and $high -ne 0} {"High";break;} 
                        {$_ -ge $medium -and $medium -ne 0} {"Medium";break;} 
                        {$_ -ge $low -and $low -ne 0} {"Low";break;} 
                        default {"Normal"} 
                        } 
                    }}
    $data = @{Name="Data";Expression={ $_ | ConvertTo-Json}}
    $alertDateTime = @{Name="DateTime";Expression={(Get-Date).ToString()}}
    $alertType = @{Name="AlertType";Expression={"LastBackup"}}

    if($LastFull) {$results = $sqlserver | Get-DbaBackupHistory -IgnoreCopyOnly -LastFull}
    elseif($lastDiff) {$results = $sqlserver | Get-DbaBackupHistory -IgnoreCopyOnly -LastDiff}
    elseif($lastLog) {$results = $sqlserver | Get-DbaBackupHistory -IgnoreCopyOnly -LastLog}

    $Results | Select ComputerName, InstanceName, SqlInstance, Database,@{Name="BackupType";Expression={$_.Type}}, @{Name="DaysSinceLastBackup";Expression={(New-Timespan $_.End $(get-date)).Days}} | `
        Select $alertDateTime, ComputerName, $AlertType , $WarningLevel , $data
  }
  
}

