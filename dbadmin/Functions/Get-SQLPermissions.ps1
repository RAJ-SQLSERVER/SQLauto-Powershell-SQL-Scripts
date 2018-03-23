function Get-SQLPermissions {
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
    [Parameter(Mandatory=$True,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
      HelpMessage='What SQL instance name would you like to target?')]
    [Alias('server ')]
    [ValidateLength(3,30)]
    [string]$instance,
	[string]$database = $null,
    [string]$object,
    [string]$login 
  )

  begin {
    
    #uncomment if not loading from dbadmin
    #write-verbose "Creating Datatable and loading SMO"
    #[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

    if($table) {$Predicate = "Where tbl.name = '$table'"} else {$predicate = $null}

    $SecurityQuery = @"
With [Principals] AS (
SELECT
	princ.principal_id
	,[UserType] = CASE princ.[type]
					WHEN 'S' THEN 'SQL User'
					WHEN 'U' THEN 'Windows User'
					WHEN 'G' THEN 'Windows Group'
					WHEN 'R' THEN 'Database Role'
					END
	,[AssignedTo] = princ.[name]
	,[AssigneeMember] = CASE
		WHEN princ.[type] IN ('R') THEN ISNULL(mprinc.[name]  , 'No Members')
		ELSE 'N/A' END
	FROM sys.database_principals princ
	LEFT JOIN (
		SELECT * FROM sys.database_role_members
		UNION ALL
		SELECT rm.role_principal_id, rm_mem.member_principal_id FROM sys.database_role_members rm
		INNER JOIN sys.database_role_members rm_mem ON rm.member_principal_id = rm_mem.role_principal_id 
		) rmem	ON princ.principal_id = rmem.role_principal_id
	LEFT JOIN sys.database_principals mprinc ON rmem.member_principal_id = mprinc.principal_id
	--LEFT JOIN #groups ad ON ((princ.name = ad.GroupName OR mprinc.name = ad.GroupName) AND ISNULL(mprinc.type, princ.type) = 'G' )
),
[Permissions] AS (
SELECT
perm.grantee_principal_id
,perm.state_desc as [PermisionState]
,perm.Permissions
,[ObjectType] = CASE 
		WHEN perm.[class] = 1 THEN obj.type_desc   -- Schema-contained objects
		ELSE perm.[class_desc]                     -- Higher-level objects
			END  
,[ObjectName] = CASE 
		WHEN perm.[class] = 1 THEN OBJECT_NAME(perm.major_id) -- General objects
		WHEN perm.[class] = 3 THEN schem.[name]               -- Schemas
		WHEN perm.[class] = 6 THEN tt.[name]				  -- Types
		ELSE 'UNKNOWN'                                        
		END
,[ColumnName] = ISNULL(col.[name],'N/A')
FROM
		(
		SELECT DISTINCT
				perm.grantee_principal_id
				,perm.[class_desc] 
				,perm.class,perm.major_id
				,perm.minor_id
				,perm.state_desc
				,[Permissions] = STUFF(( SELECT DISTINCT ',' + p1.[permission_name] 
						FROM sys.database_permissions p1 WHERE p1.grantee_principal_id = perm.grantee_principal_id 
						AND (p1.major_id = perm.major_id AND p1.minor_id = perm.minor_id AND p1.state_desc = perm.state_desc)
						FOR XML PATH('')), 1, 1, '')
		FROM sys.database_permissions perm
		) perm 
LEFT JOIN sys.all_objects obj ON perm.[major_id] = obj.[object_id] AND perm.class = 1
LEFT JOIN sys.columns col ON col.[object_id] = perm.major_id AND col.[column_id] = perm.[minor_id] AND perm.class = 1
LEFT JOIN sys.schemas schem ON schem.[schema_id] = perm.[major_id] AND perm.class = 3
LEFT JOIN sys.table_types tt ON tt.user_type_id = perm.major_id AND perm.class = 6
--WHERE CASE 
--		WHEN perm.[class] = 1 THEN OBJECT_NAME(perm.major_id) -- General objects
--		WHEN perm.[class] = 3 THEN schem.[name]               -- Schemas
--		WHEN perm.[class] = 6 THEN tt.[name]				  -- Types
--		ELSE 'UNKNOWN'                                        
--		END = @object
)
SELECT
		@@SERVERNAME AS [SQLInstance] ,
		DB_NAME() AS [DatabaseName]  ,
		[UserType] = [UserType] COLLATE Latin1_General_CI_AS ,
		[AssignedTo] = [AssignedTo] COLLATE Latin1_General_CI_AS ,
		[AssigneeMember] = [AssigneeMember] COLLATE Latin1_General_CI_AS ,
		[ObjectType] = [ObjectType] COLLATE Latin1_General_CI_AS ,
		[ObjectName] = [ObjectName] COLLATE Latin1_General_CI_AS ,
		[ColumnName] = [ColumnName] COLLATE Latin1_General_CI_AS ,
		[PermisionState] = [PermisionState] COLLATE Latin1_General_CI_AS ,
		[Permissions] = [Permissions]  COLLATE Latin1_General_CI_AS    
FROM [Principals] PR
LEFT JOIN [Permissions] PM ON PM.grantee_principal_id = PR.principal_id
UNION ALL
SELECT DISTINCT 
		@@SERVERNAME AS [SQLInstance],
		DB_NAME() AS [DatabaseName],
		[UserType] = 'Server Role',
		[AssignedTo] = serverrole,
		[AssigneeMember] = Name,
		[ObjectType] = 'DATABASE',
		[ObjectName] = 'All',
		[ColumnName] = NULL,
		[PermisionState] = 'GRANT',
		[Permissions] = CASE 
				WHEN serverrole = 'sysadmin' THEN 'ALL'
				WHEN serverrole = 'securityadmin' THEN 'ALTER ANY LOGIN'
				WHEN serverrole = 'serveradmin' THEN 'ALTER ANY ENDPOINT, ALTER RESOURCES, ALTER SERVER STATE, ALTER SETTINGS, SHUTDOWN, VIEW SERVER STATE'
				WHEN serverrole = 'setupadmin' THEN 'ALTER ANY LINKED SERVER'
				WHEN serverrole = 'processadmin' THEN 'ALTER ANY CONNECTION, ALTER SERVER STATE'
				WHEN serverrole = 'diskadmin' THEN 'ALTER RESOURCES'
				WHEN serverrole = 'dbcreator' THEN 'CREATE ANY DATABASE'
				WHEN serverrole = 'bulkadmin' THEN 'ADMINISTER BULK OPERATIONS'
				END
FROM sys.syslogins AS SL 
UNPIVOT(
perms
FOR serverrole in (sysadmin,securityadmin,serveradmin,setupadmin,processadmin,diskadmin,dbcreator,bulkadmin)
) unpiv
WHERE perms=1
"@

  } #End on Begin

  process {

        write-verbose "Beginning process loop"

        $server = New-Object "Microsoft.SqlServer.Management.Smo.Server" $instance
        write-verbose $server.name

        if ($database) {
            write-verbose "processing database parameter"
            $dbs = $server.Databases[$database]
        } else {
            write-verbose "No database parameter set processing all databases"
            $dbs = $server.Databases
        }

        if ($dbs) {   
            foreach ($db in $dbs) {
            write-verbose $db.Name
            $Permissions += ($db.ExecuteWithResults($SecurityQuery)).Tables[0];
            #foreach ($detail in $Permissions)
			#	{
            #        [pscustomobject]@{
            #            Instance = $instance; 
            #            DatabaseName = $db.Name;
            #            UserType = $detail.UserType; 
            #            Assignee = $detail.AssignedTo; 
            #            AssigneeMember = $detail.AssigneeMember; 
            #            ObjectType = $detail.ObjectType; 
            #            ObjectName =  $detail.ObjectName;
            #            ColumnName = $detail.ColumnName;
            #            PermissionState =  $detail.PermissionState
            #            Permissions = $detail.Permissions
            #        }
            #    }
            }
        }
        Else {
            Write-Warning "Could not find a database called $database on $instance"
		    continue
        }

        if($permissions) {Return $permissions}
        
    } # End of Process

}
