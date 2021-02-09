function Get-ADUserGroupMembershipRecursive {
  <#
  .SYNOPSIS
  Get recursive list of group membership in AD by user
  .DESCRIPTION
  Get recursive list of group membership in AD by user 
  .NOTES
  Tags: Active Directory, Group, Membership
  Original Author: Vadims Podāns
  
  https://www.sysadmins.lv/blog-en/efficient-way-to-get-ad-user-membership-recursively-with-powershell.aspx
   
  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
  You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
  .EXAMPLE
  Give an example of how to use it
  .PARAMETER UserName
  The user to query, just one.
  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String[]]$UserName
    )

  begin {
        # introduce two lookup hashtables. First will contain cached AD groups,
        # second will contain user groups. We will reuse it for each user.
        # format: Key = group distinguished name, Value = ADGroup object
        $ADGroupCache = @{}
        $UserGroups = @{}
        # define recursive function to recursively process groups.
        function __findPath ([string]$currentGroup) {
            Write-Verbose "Processing group: $currentGroup"
            # we must do processing only if the group is not already processed.
            # otherwise we will get an infinity loop
            if (!$UserGroups.ContainsKey($currentGroup)) {
                # retrieve group object, either, from cache (if is already cached)
                # or from Active Directory
                $groupObject = if ($ADGroupCache.ContainsKey($currentGroup)) {
                    Write-Verbose "Found group in cache: $currentGroup"
                    $ADGroupCache[$currentGroup]
                } else {
                    Write-Verbose "Group: $currentGroup is not presented in cache. Retrieve and cache."
                    $g = Get-ADGroup -Identity $currentGroup -Property "MemberOf"
                    # immediately add group to local cache:
                    $ADGroupCache.Add($g.DistinguishedName, $g)
                    $g
                }
                # add current group to user groups
                $UserGroups.Add($currentGroup, $groupObject)
                Write-Verbose "Member of: $currentGroup"
                foreach ($p in $groupObject.MemberOf) {
                    __findPath $p
                }
            } else {Write-Verbose "Closed walk or duplicate on '$currentGroup'. Skipping."}
        }
  }

  process {

        foreach ($user in $UserName) {
            Write-Verbose "========== $user =========="
            # clear group membership prior to each user processing
            $UserObject = Get-ADUser -Identity $user -Property "MemberOf"
            $UserObject.MemberOf | ForEach-Object {__findPath $_}
            New-Object psobject -Property @{
                UserName = $UserObject.Name;
                MemberOf = $UserGroups.Values | % {$_}; # groups are added in no particular order
            }
            $UserGroups.Clear()
        }
  }
}
