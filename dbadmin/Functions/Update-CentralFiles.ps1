function Update-CentralFiles {
  <#
  .SYNOPSIS
  function to perform a push / pull style sync of two folders
  .DESCRIPTION
  This function will compare files from source and destination and based on whether the switch parameters have been specified will either copy or delete files to source or destination
  .NOTES
  Tags: File, synchronisation
  Original Author: Ian Pain  
  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
  You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
  .EXAMPLE
  Update-CentralFiles -SourcePath c:\temp -DestinationPath d:\temp -Push
  .EXAMPLE
  Update-CentralFiles -SourcePath c:\temp -DestinationPath d:\temp -Pull
  .PARAMETER SourcePath
  The path that will be used as the source, in most cases this will be the local copy.
  .PARAMETER DestinationPath
  The path that will be used as the destination, in most cases this will be a remote directory
  .PARAMETER Push
  Specify whether you would like to push changes from source to destination
  .PARAMETER Pull
  Specify whether you would like to pull changes from destination to source
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True)]
    [string]$SourcePath,
    [Parameter(Mandatory=$True)]
    [string]$DestinationPath,	
    [switch]$Push,
    [switch]$pull
  )

  begin {
    write-verbose "Starting process"
    if(!(Test-Path -Path $SourcePath)) {Write-Error "Source path does not exist" -ErrorAction Stop}
    if(!(Test-Path -Path $DestinationPath)) {Write-Error "Destination path does not exist" -ErrorAction Stop}
    if($Push -eq $false -and $pull -eq $false) {Write-Error "You must declare either Push or Pull using either -Push or Pull as a parameter" -ErrorAction Stop}
  }

  process {

    write-verbose "Beginning process loop"

    $SourceFiles = Get-ChildItem -Path $SourcePath -Recurse | Where-Object{!($_.PSIsContainer)} | Select  @{Name="FullName";Expression={$($_.FullName -replace([regex]::escape($SourcePath)))}},@{Name="Directory";Expression={$($_.Directory -replace([regex]::escape($SourcePath)))}} 
    $DestinationFiles = Get-ChildItem -Path $DestinationPath -Recurse | Where-Object{!($_.PSIsContainer)} | Select  @{Name="FullName";Expression={$($_.FullName -replace([regex]::escape($DestinationPath)))}},@{Name="Directory";Expression={$($_.Directory -replace([regex]::escape($DestinationPath)))}}

    $Results = @()

    if($DestinationFiles -eq $null -and $push) {
        #Destination empty so copy all files
        write-host "Copying all files as no objects exist at destination"
        foreach($file in $SourceFiles) {
            #write-host "$SourcePath$($file.Directory)\$($file.Name)"
            Copy-Item -path "$SourcePath$($file.FullName)" -Destination (New-Item "$DestinationPath$($file.Directory)\" -ItemType Directory -Force)
        } 
    }
    else {
        #Destination has files so we need to sync
        $Diff = Compare-Object $SourceFiles $DestinationFiles -Property FullName, Directory -IncludeEqual

        foreach($file in $Diff) {
            if ($file.SideIndicator -eq '<=') {
                $Results += [pscustomobject]@{Type = %{if($push){"New"}else{"New"}}; FullName = $file.FullName; Directory = $file.Directory; Description = %{if($push){"Copy file from source to destination"}else{"Delete file from source"}}; Action = %{if($push){"Copy"}else{"Delete"}}}
            }
            elseif ($file.SideIndicator -eq '=>') {
                $Results += [pscustomobject]@{Type = %{if($push){"Delete"}else{"New/Restore"}}; FullName = $file.FullName; Directory = $file.Directory; Description = %{if($push){"Delete file from destination"}else{"Copy file from destination to source"}}; Action = %{if($push){"Delete"}else{"Copy"}}}
            }
            else {
                $updated =  Compare-Object $(Get-FileHash -Path "$SourcePath$($file.Fullname)").Hash $(Get-FileHash -Path "$DestinationPath\$($file.Fullname)").Hash -IncludeEqual
                If($updated.SideIndicator -ne "==") {
                    $Results += [pscustomobject]@{Type = "Updated"; FullName = $file.FullName; Directory = $file.Directory; Description = %{if($push){"Copy file from source to destination"}else{"Copy file from destination to source"}}; Action = "Copy"}
                }
            }
        }
    }
    $action = $null
    $actions = $Results | Out-GridView -PassThru

    if ($actions -and $Push) {
        $actions | Where {$_.Action -eq "Copy"} | ForEach-Object { Copy-Item -Path "$SourcePath$($_.FullName)" -Destination (New-Item "$DestinationPath$($_.Directory)" -type Directory  -Force) -Force }
        $actions | Where {$_.Action -eq "Delete"} | ForEach-Object { Remove-Item -path "$DestinationPath$($_.FullName)" -Force }
    }
    elseif ($actions -and $pull) {
        $actions | Where {$_.Action -eq "Copy"} | ForEach-Object { Copy-Item -Path "$DestinationPath$($_.FullName)" -Destination (New-Item "$SourcePath$($_.Directory)" -type Directory -Force)  -Force }
        $actions | Where {$_.Action -eq "Delete"} | ForEach-Object { Remove-Item -path "$SourcePath$($_.FullName)" -Force }
    }
    else  {
        write-host "All files are in sync" -ForegroundColor Green
    }

  }
}
