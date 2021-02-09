Function Expand-CmsServerGroup($serverGroup,$collection) {
 
    foreach ($instance in $serverGroup.RegisteredServers) {
        $urn = $serverGroup.urn
        $group = $serverGroup.name
        $fullgroupname = $null
 
        for ($i = 0; $i -lt $urn.XPathExpression.Length; $i++) {
            $groupname = $urn.XPathExpression[$i].GetAttributeFromFilter("Name")

            if ($groupname -eq "DatabaseEngineServerGroup") { $groupname = $null }

            if ($i -ne 0 -and $groupname -ne "DatabaseEngineServerGroup" -and $groupname.length -gt 0 ) {
                $fullgroupname += "$groupname\"
            }
        }
 
        if ($fullgroupname.length -gt 0) { 
            $fullgroupname = $fullgroupname.TrimEnd("\") 
        }

        $object = New-Object PSObject -Property @{
                Server = $instance.servername
                Group = $groupname
                FullGroupPath = $fullgroupname
                }
        $collection += $object
    }
 
    foreach($group in $serverGroup.ServerGroups)
    {
        $newobject = (Expand-CmsServerGroup -serverGroup $group -collection $newcollection)
        $collection += $newobject     
    }
    return $collection
}