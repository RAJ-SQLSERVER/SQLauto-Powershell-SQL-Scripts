Function global:GET-OpenFilePID() 
                { 
                                param 
                                ( 
                                [parameter(ValueFromPipeline=$true, 
                                                Mandatory=$true)] 
                                [String[]]$HandleData 
                                ) 
                                 
                                Process 
                                { 
                                                $OpenFile=New-Object PSObject -Property @{FILENAME='';ProcessPID='';FILEID=''} 
                                                 
                                                $StartPid=($HandleData[0] | SELECT-STRING 'pid:').matches[0].Index 
                                                $OpenFile.Processpid=$HandleData[0].substring($StartPid+5,7).trim() 
                                                 
                                                $StartFileID=($HandleData[0] | SELECT-STRING 'type: File').matches[0].Index 
                                                $OpenFile.fileid=$HandleData[0].substring($StartFileID+10,14).trim() 
                                                 
                                                $OpenFile.Filename=$HandleData[0].substring($StartFileID+26).trim() 
                                                Return $OpenFile 
                                } 
                } 
