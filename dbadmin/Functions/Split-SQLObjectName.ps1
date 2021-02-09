Function Split-SQLObjectName {

	[CmdletBinding()]
	Param (
		[parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
		[Alias("ServerInstance", "SqlServer")]
		[String]$ObjectName
	)

    Process {
        #$ObjectName = "[database].[test].[tablename]"
        [String[]]$Result = ($ObjectName -replace '[[\]]','').Split(".")
        $i = $result.Length -1
        [pscustomobject]@{
            ObjectName = $Result[$i];
            ObjectSchema = If($i -ne 0) { $Result[($i-1)] } else { "dbo" };
            Parent = If($i -gt 1) { $Result[($i-2)] };
        }
    }

}