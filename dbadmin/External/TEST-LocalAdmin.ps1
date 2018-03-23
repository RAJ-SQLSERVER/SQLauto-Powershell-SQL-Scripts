Function global:TEST-LocalAdmin() 
                { 
                Return ([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] "Administrator") 
                } 