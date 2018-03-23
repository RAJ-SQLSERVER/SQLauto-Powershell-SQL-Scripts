Function global:Close-Openfile() 
{ 
[CmdletBinding(SupportsShouldProcess=$true)] 
Param( 
                [parameter(Mandatory=$True, 
                                ValueFromPipelineByPropertyName=$True)] 
                                [string[]]$ProcessPID, 
                [parameter(Mandatory=$True, 
                                ValueFromPipelinebyPropertyName=$True)] 
                                [string[]]$FileID, 
                [parameter(Mandatory=$false, 
                                ValueFromPipelinebyPropertyName=$True)] 
                                [String[]]$Filename 
                ) 
                 
                Process 
                { 
        $HANDLEAPP="& '$PSScriptRoot\handle.exe'"                 
        $Expression=$HANDLEAPP+' -p '+$ProcessPID[0]+' -c '+$FileID[0]+' -y' 
                if ( $PSCmdlet.ShouldProcess($Filename) )  
                                { 
                                INVOKE-EXPRESSION $Expression | OUT-NULL 
                                If ( ! $LastexitCode ) { Write-host 'Successfully closed'} 
                                } 
                } 
} 
