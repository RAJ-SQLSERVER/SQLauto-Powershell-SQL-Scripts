function Invoke-CheckAppLogEvents {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    <#
      NOTE: If SQL is using the "-n" startup paramenter, then SQL does not 
      write to the Windows Application log, and this will always return no errors.
      https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/database-engine-service-startup-options
    #>

    #Get the physical hostname
    $server = Get-SqlConnection $targetServer

    if($server.TrueName.Split('\')[1]) {
        $source = "MSSQL`$$($server.TrueName.Split('\')[1])"
    }
    else {
        $source = 'MSSQLSERVER'
    }

    $cmd = "SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS');"
    try {
        $computerName = $server.ExecuteScalar($cmd)
    }
    catch {
        Get-Error $_
    }
    
    #ErrorAction = SilentlyConintue to prevent "No events were found"
    $events = $null
    $events = Get-WinEvent -ComputerName $computerName -FilterHashtable @{LogName='Application';Level=2;StartTime=((Get-Date).AddDays(-1));ProviderName=$source} -ErrorAction SilentlyContinue

    if ($events) {
        #Display the results to the console
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
        Write-Host "Found $($events.Count) error(s)! Showing only the most recent events:"
        $events | Select-Object TimeCreated,@{Label='EventID';Expression={$_.Id}},Message | Format-Table -AutoSize
    }
    else { Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)" }
} #Get-AppLogEvents