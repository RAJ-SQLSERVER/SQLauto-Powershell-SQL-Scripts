function Get-StringEncryption {
  <#
  .SYNOPSIS
  Encrypts and Decrypts a string
  .DESCRIPTION
  Using a standard key encrypt a plain text string or using the same key decrypt an ecncrypted sting back to plain text
  .NOTES
  Tags: Encryption
  Original Author: Ian Pain  
  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
  You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
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
      HelpMessage='Specify the string to encrypt or decrypt?')]
    [string[]]$Value,	
    [switch]$Encrypt,
    [switch]$Decrypt
  )

  begin {
    Write-Verbose "Setting key value"
    $privatekey = "Thisissomerandomkey123!"
    $length = $privatekey.length
    $pad = 32-$length
    if (($length -lt 16) -or ($length -gt 32)) {
        Throw "String must be between 16 and 32 characters"
       }
    $encoding = New-Object System.Text.ASCIIEncoding
    $key = $encoding.GetBytes($privatekey + "0" * $pad)
  }

    process {

        write-verbose "Beginning process loop"

        if(-not $Decrypt -and -not $Encrypt) {
            Throw "You must specify to either encrypt or decrypt specified value"
        }

        foreach ($string in $Value) {
            if($encrypt) {
                $securestring = new-object System.Security.SecureString
                $chars = $string.toCharArray()
                foreach ($char in $chars) {$secureString.AppendChar($char)}
                ConvertFrom-SecureString -SecureString $secureString -Key $key

            }
            if($decrypt) {
                $string | ConvertTo-SecureString -key $key |
                ForEach-Object {[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($_))}
            }
        }

    }
}
