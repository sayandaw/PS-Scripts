## Defines Input CSV
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$false,Position=1)]
   [string]$XMLFileName="Change-CD.csv"
)
$VCServer = "##################################################"

## Set Directory to current Script location
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
cd $ScriptDir


## Write-Log
$global:LogFilePath = 'PSLogFile.log'
function Write-Log
{
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('1','2','3')]
        [int]$Severity = 1 ## Default to a low severity. Otherwise, override
    )
    
    $line = [pscustomobject]@{
        'DateTime' = (Get-Date)
        'Message' = $Message
        'Severity' = $Severity
    }
    
    ## Ensure that $LogFilePath is set to a global variable at the top of script
	Write-Verbose -Message $line
    $line | Export-Csv -Path $LogFilePath -Append -NoTypeInformation
}
Write-Log -Message "$LogFilePath is the log file in $ScriptDir" -Severity 1


## Deploy VMs from CSV File
Write-Log -Message "Connecting $VCServer" -Severity 1
Connect-VIServer -Server $VCServer

## Imports CSV file
Import-Csv $XMLFileName -UseCulture | ForEach-Object {

$ISODatastore = $_."ISODatastore"
$ISO = $_."ISO"
$OSImagePath = "[$ISODatastore]ISO\$ISO"

## Mount boot image.
Write-Log -Message "Mapping $OSImagePath to CD Drive for $_.VMName" -Severity 1
$VCD = Get-CDDrive -VM $_."VMName"
Set-CDDrive -CD $VCD -IsoPath "$OSImagePath" -StartConnected:$True -Confirm:$False -ErrorAction Stop | Out-Null
}

### Disconnect from vCenter.
Write-Log -Message "Disconnecting $VCServer" -Severity 1
Disconnect-VIServer -Confirm:$false
