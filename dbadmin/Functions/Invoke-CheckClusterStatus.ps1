function Invoke-CheckClusterStatus {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    $cmd = @"
    SELECT
         NodeName AS cluster_node_name
        ,UPPER(status_description) AS cluster_node_status
    FROM sys.dm_os_cluster_nodes
    UNION
    SELECT
         member_name AS cluster_node_name
        ,member_state_desc AS cluster_node_status
    FROM sys.dm_hadr_cluster_members
    WHERE member_type = 0;
"@

    #If one exists, get status of each Availability Group
    $server = Get-SqlConnection $targetServer
    try {
        $results = $server.ExecuteWithResults($cmd)
    }
    catch {
        Get-Error $_ -ContinueAfterError
    }

    #Display the results to the console
    if ($results.Tables[0].Rows.Count -ne 0) {
        if ($results.Tables[0] | Where-Object {$_.cluster_node_status -ne 'UP'}) {
            Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
        }
        else { Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)" }
    }

    #Display the results to the console
    if ($results.Tables[0] | Where-Object {$_.cluster_node_status -ne 'UP'}) {
        $results.Tables[0] | ForEach-Object {
            if ($_.cluster_node_status -ne 'UP') {
                Write-Host "$($_.cluster_node_name): $($_.cluster_node_status)" -BackgroundColor Red -ForegroundColor White
            }
            else {
                Write-Host "$($_.cluster_node_name): $($_.cluster_node_status)"
            }
        }
    }
    if ($results.Tables[0].Rows.Count -eq 0) {
      Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
      Write-Host '*** No cluster detected ***'
    }
} #Get-ClusterStatus