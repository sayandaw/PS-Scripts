## Defines Input CSV
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$false,Position=1)]
   [string]$XMLFileName="Create-VM.csv"
)
$VCServer = "#######################################################"

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

## Initializes VMWare PowerShell SnapIn
$SnapInName = "VMware.VimAutomation.Core"
$SnapInAdded = Get-PSSnapin | Select-String $SnapInName
If ( !$SnapInAdded )
{
    Add-PSSnapin $SnapInName
	Write-Log -Message "$SnapInName is added" -Severity 1
    If ( ! $? ) {  Write-Log -Message "$SnapInName is NOT FOUND on SYSTEM" -Severity 3 exit }
} else { Write-Log -Message "$SnapInName is already added" -Severity 3 }

## Deploy VMs from CSV File
Write-Log -Message "Connecting $VCServer" -Severity 1
Connect-VIServer -Server $VCServer

## Imports CSV file
Import-Csv $XMLFileName -UseCulture | ForEach-Object {

$ISODatastore = $_."ISODatastore"
$ISO = $_."ISO"
$OSImagePath = "[$ISODatastore]ISO\$ISO"

## Creates the New VM
$NewVM = Get-VM -Name $_."VMName"
If ( !$NewVM )
{	
	$params = @{

		Name				= $_."VMName"
        Host                = $_."ESX"
		NumCPU				= $_."vCPUCount"
		MemoryGB			= $_."vRAMSizeGB"
		DiskGB				= $_."vDiskSizeGB"      
		DiskStorageFormat	= $_."DiskType"
		Datastore			= $_."Datastore"
		Version				= $_."Version"
		CD					= $True
		Network				= $_."Network"
		GuestId				= $_."GuestID"
		Notes				= $_."Description"
        Location            = $_."Location"
	}
Write-Log -Message "Creating new VM with $params" -Severity 1
$NewVM = New-VM @params -ErrorAction Stop -Confirm:$false
## Set network adapter to VMXNET3.
Write-Log -Message "Set-NetworkAdapter on VM with type vmxnet3" -Severity 1
Get-NetworkAdapter -VM $NewVM | Set-NetworkAdapter -Type "vmxnet3" -Confirm:$false | Out-Null
## Add custom VMX entries.
Write-Log -Message "SMBIOS.AssetTag -Value $_."SMBIOS.AssetTag"" -Severity 1
$NewVM | New-AdvancedSetting -Name SMBIOS.AssetTag -Value $_."SMBIOS.AssetTag" -Confirm:$false | Out-Null
Write-Log -Message "machine.id -Value $_."VMName"" -Severity 1
$NewVM | New-AdvancedSetting -Name machine.id -Value $_."VMName" -Confirm:$false | Out-Null

## Mount boot image.
Write-Log -Message "Mapping $OSImagePath to CD Drive" -Severity 1
$VCD = Get-CDDrive -VM $_."VMName"
Set-CDDrive -CD $VCD -IsoPath "$OSImagePath" -StartConnected:$True -Confirm:$False -ErrorAction Stop | Out-Null
}
}
### Disconnect from vCenter.
Write-Log -Message "Disconnecting $VCServer" -Severity 1
Disconnect-VIServer -Confirm:$false