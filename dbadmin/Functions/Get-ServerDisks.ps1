function Get-ServerDisks {
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
    [string[]]$ComputerName = $env:COMPUTERNAME
  )

  begin {
    $SelectList = @{Expression={$item};Label="ComputerName"}, @{Expression={$_.DriveLetter};Label="DiskName"}, `
            @{Expression={$_.Label};Label="Label"}, `
            @{Expression={$_.FileSystem};Label="FileSystem"}, `
            @{Expression={[int]$($_.BlockSize/1KB)};Label="BlockSizeKB"}, `
            @{Expression={[int]$($_.Capacity/1MB)};Label="CapacityMB"}, `
            @{Expression={[int]$($_.Freespace/1MB)};Label="FreeSpaceMB"}
  }

  process {
    foreach($item in $ComputerName) {
        Write-Verbose "Processing $item"
        $disks += Get-WmiObject Win32_Volume -ComputerName $item | Where {$_.DriveType -eq 3} | Sort-Object DriveLetter | Select $SelectList
    }
    $disks
  }
  
}