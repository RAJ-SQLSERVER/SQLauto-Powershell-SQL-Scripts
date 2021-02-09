function  Get-ADGroupMembershipRecursive {

  param (
  [Parameter()]
  [string]$Server,
  [string]$Identity,
  [array]$parents
  )
  $parents += $parents

  $daMembers = Get-ADGroupMember -Identity $Identity -Server $server

  $daMembers | foreach {  
    if ($_.objectClass  -eq 'group' -and ($_.name -ne "Domain Users" -and $_.name -ne $identity)) {
        ## Check if we've previous processed the group to avoid circular references
        if($parents -notcontains $_.SamAccountName) {
            write-verbose (" {0} : Processing {1} " -f $MyInvocation.MyCommand, $($_.SamAccountName))
            $parents += $_.SamAccountName
            Get-ADGroupMembershipRecursive  -Identity $_.SamAccountName -Server $server -parents $parents
        }
        else {
            write-verbose (" {0} : Skipping {1} " -f $MyInvocation.MyCommand, $($_.SamAccountName))
        }
    } else {
        ## Send the non-group object out
        [pscustomobject]@{
            Name = $_.Name
            ObjectGUID = $_.ObjectGUID
        }
    }

  }

}

#$users = Get-ADGroupMembershipRecursive -Server "MEARSDOM" -Identity "PermEnableIEdonotsaveencryptedpages" -Verbose

#Get-ADGroup -Identity "Domain Users" -Properties members | Select -ExpandProperty members

#Get-ADGroup -Filter "*" | Where-Object {$_.name -ne $_.SamAccountName} | Select Name, SamAccountName

