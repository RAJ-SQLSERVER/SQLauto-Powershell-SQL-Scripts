Function Get-Error {
<#
Simple function that generates an error
#>
[CmdletBinding()]
Param()

    process{
        Write-Warning ("Unknown error getting library. The specific error message is: {0}" -f $_.Exception.Message)
    }

}