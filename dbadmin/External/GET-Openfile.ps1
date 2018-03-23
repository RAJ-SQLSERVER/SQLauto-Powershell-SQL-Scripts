<#
.SYNOPSIS
   Searches for all handles currently open by the provided user.
.DESCRIPTION
   Uses Handle.exe created by Mark Russinovich at SysInternals.
   Uses the custom Handle class to store the information.
.EXAMPLE
   Get-Handle -username test
   This command will output all handles found for the user "test".
.EXAMPLE
   Get-Handle -user "test user"
   This command will output all handles found for the user "test user". Quotes are only required if the
   username contains a space.
.EXAMPLE
   Get-Handle -user test -servers (comp1, comp2)
   This command will output all handles found for the user "test" on the machines named "comp1"
   and "comp2".
.INPUTS
   A required <String> and an optional <String[]>.
.LINK
   New-Handle
   Close-Handle
.NOTES
   This function will parse the output of Handle.exe, extracting the seven handle properties for each
   handle found under the given username. It will call New-Handle to store each one found and will output an
   array of these custom handle objects.
   
   @Author: xXBlu3f1r3Xx
   @LEDate: July 25th, 2015
   @PSVers: 2.0+
#>
function Get-Handle {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    Param (
        # Username to search handles for
        [Parameter(Mandatory=$true,
                   HelpMessage="Enter a username")]
        [alias("u")]
        [alias("user")]
        [string]
        $username,
		
		# Server(s) to query. If not specified the function will run on the machine calling it.
		[Parameter()]
		[alias("server")]
		[alias("v")]
		[string[]]
		$servers
    )
	BEGIN {
		# Populate serverList if servers weren't passed to the function
		$serverList = @()
		if (!($servers)) {
			$serverList = $env:computername		# default to the machine running this function
		}
		else {
			$serverList = $servers
		}
		
		# I am currently researching quicker methods of finding handles.
		# I may end up making my own compiled program instead of relying on Handle.exe
		Write-Host "Beginning handle search..." -f yellow -b black
		Write-Host "Expect this to take 20-90 seconds, dependent on the available resources." -f yellow -b black
		Write-Host " "

		$foundHandles = @()
		$sw = [Diagnostics.Stopwatch]::StartNew()		# To test the run time of this loop
	}
	PROCESS {
		$foundHandles += Invoke-Command -ComputerName $serverList -ScriptBlock {
			$username = $args[0]
			#Import-Module "C:\HandleToolsV1.psm1"
		
			# Regular expressions to match the lines to
			$regexp1 = "^([^ ]+)\spid:\s(\d+)\s([\s*\S*]+)$"
			$regexp2 = "^([(0-9)*(A-F)*]+):\s([^ ]+)\s{2}(\([[RWD-]{3}]?\))\s*([\s*\S*]*$username[\s*\S*]*)$"
			$regexp3 = "^([(0-9)*(A-F)*]+):\s([^ ]+)\s*([\s*\S*]*$username[\s*\S*]*)$"
		
			$PSHandles = New-Object System.Collections.Generic.List[PSCustomObject]
			$procInfo = ("", 0, "", "", "", "", "")		# passed as parameter to Create-Handle
			$handles = (INVOKE-EXPRESSION "& 'E:\powershell\scripts\modules\dbadmin\external\handle.exe'")
			
			for ($i = 5; $i -lt $handles.Length; $i++) {
				$line = [string]$handles[$i].trim()
			
				# Indicates start of new process
				if ($line.SubString(0, 1) -eq "-") {
					$i++		# Move to the next line
					$line = [string]$handles[$i].trim()
					# Match to regular expression for this line and extract info
					$valid1 = $line -match $regexp1
					if ($valid1) {
						$procInfo[0] = [String]$Matches[1]
						$procInfo[1] = [int]$Matches[2]
						$procInfo[2] = [String]$Matches[3]
					}
				
					# Prep for first file handle from this process
					$i++
					$line = [string]$handles[$i].trim()
				}
			
				# Match to regular expression for the file handle lines and extract info
				$valid2 = $line -match $regexp2
				
				if ($valid2) {		# If it matches regexp2 it is a File and has the access property
					$procInfo[3] = [String]$Matches[1]
					$procInfo[4] = [String]$Matches[2]
					$procInfo[5] = [String]$Matches[3]
					$procInfo[6] = [String]$Matches[4]
				}
				else {	
					$valid3 = $line -match $regexp3
					if ($valid3) {		# If it matches regexp3 it is some type other than File and skips the access property
						$procInfo[3] = [String]$Matches[1]
						$procInfo[4] = [String]$Matches[2]
						$procInfo[5] = ""
						$procInfo[6] = [String]$Matches[3]
					}
					else {		# skip storing this one if it doesn't match the regex
						Clear-Variable Matches
						continue		
					}
				}

				Clear-Variable Matches

				$tempHandle = New-Handle -props $procInfo
				$PSHandles.add($tempHandle)	
			}
			
			Return $PSHandles
		} -ArgumentList $username
	}
	END {
		$sw.Stop()
		$ts = $sw.Elapsed
		$elapsedTime = "$($ts.minutes):$($ts.seconds).$($ts.milliseconds)"
		Write-Host "Elapsed time (minutes:seconds.milliseconds) -> " -nonewline; Write-Host $elapsedTime -f yellow -b black
		Write-Host " "

		# Return search results
		$foundHandles | Sort-Object -Property PSComputerName, ProcessId
	}
}