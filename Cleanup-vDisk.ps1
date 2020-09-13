#Requires -RunAsAdministrator
<#
Provisioning Services vDisk Cleanup
Written by David Ott
Have you ever noticed that when you delete an old vDisk version or version chain that the files in the store aren't always
deleted?
I got tired of checking behind manually, and wrote this quick script.  As long as you run this from one of your Provisioning
Servers as an administrator it should work without modification.  Explanation of certain sections marked with "#####".
#>
 
<##### 
This function looks in each store root for files that match the base file name of the vDisk, gets the version
number from the file name, and compares that version to the versions PVS knows of.  If the file version is not contained
in the list of versions for that vdisk it will flag it for deletion.
#####>
function find-oldvdisks($rs,$fn,$lv) {
foreach ($r in $rs) {
(gci $r "*$fn*").fullname | %{
$v = ($_ -split "\.")[($_ -split "\.").count - 2] | ?{$_ -match "^\d+"}
if ($v -eq $null) {$v = 0}
if (($lv -notcontains $v)) {
$_
}
}
}
}
##### imports PVS module
ipmo 'C:\Program Files\Citrix\Provisioning Services Console\Citrix.PVS.SnapIn.dll'
##### gets info on all vDisks
$vdisks = Get-PvsDiskInfo
##### sets a blank array
$ovdisks = @()
<#####
Gets the unc path for each vDisk (ie:\\server\d$\Store\2016image.20.vhdx).  Using that information it breaks down
the file name into the base and the version number.  Finally it sends the store root path (ie: \\server\d$\Store), 
the root file name (ie: 2016image) and the version numbers that PVS knows about (ie: 20).
The reply from the function is stored in the $ovdisks array
#####>
foreach ($vdisk in $vdisks) {
$vdiskinventory = Get-PvsDiskInventory -DiskLocatorId $vdisk.DiskLocatorId | select version,@{n='filepath';e={if ($_.filepath -like "\\*"){
$_.filepath
} else {
$drive = ($_.filepath -split ":")[0];`
$servername = $_.servername;`
$fpath = ($_.filepath -split ":")[1];`
"\\$servername\$drive`$$fpath"}}} | %{
$version = $_.version
$rootpath = $_.filepath
Join-Path $rootpath (Get-PvsDiskVersion -DiskLocatorId $vdisk.DiskLocatorId | ?{$_.version -eq $version}).DiskFileName
}
$vdiskversions = (Get-PvsDiskVersion -DiskLocatorId $vdisk.DiskLocatorId).version
$rootstores = $vdiskinventory | %{Split-Path $_ -Parent} | sort -Unique
$filename = $vdiskinventory | %{Split-Path $_ -leaf} | %{($_ -split "\.")[0]}| sort -Unique
$ovdisks += find-oldvdisks -rs $rootstores -fn $filename -lv $vdiskversions
}
if (($ovdisks | measure).count -eq 0) {
Write-Host "No old vDisks to clean up"
}
<#####
Shows the vDisk files (vhd(x), pvp, lok) in a grid view gui, and allows you to select the files to delete
#####>
$deletes = $ovdisks | Out-GridView -Title "Select vDisks to delete" -OutputMode Multiple
##### Deletes the files
$deletes | %{
ri $_ -Force -Verbose
}


Get-PvsDiskInfo | select name, devicecount, writecachetype | Out-GridView -Title "Select vDisks to delete" -OutputMode Multiple
