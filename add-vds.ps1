$VCSAIPAddress = "192.168.30.100"
$VCSASSODomainName = "pklab.local"
$VCSASSOPassword = "VMware1!"
$NewVCDatacenterName = "Datacenter"
$NewVCVSANClusterName = "cluster-01"
$ESXiVLAN = "3116"
$VMNetmask = "255.255.255.0"
$NetworkSubnet = "192.168.30."



$MgmtVDSName = "management-VDS"
$MgmtDVPGName = "Management Network"
$vMotionDVPGName = "vMotion Network"
$VSANDVPGName = "VSAN Network"

#My-Logger "Connecting to the VCSA ..."
$vc = Connect-VIServer $VCSAIPAddress -User "administrator@$VCSASSODomainName" -Password $VCSASSOPassword -WarningAction SilentlyContinue

#My-Logger "Creating VDS ..."
#New-VDSwitch -Name $MgmtVDSName -Location $NewVCDatacenterName -NumUplinkPorts 2 -Mtu 1600
#New-VDPortgroup -VDSwitch $MgmtVDSName -Name $MgmtDVPGName -VlanId $ESXiVLAN -Confirm:$false | Out-Null
#New-VDPortgroup -VDSwitch $MgmtVDSName -Name $vMotionDVPGName -VlanId $ESXiVLAN -Confirm:$false | Out-Null
#New-VDPortgroup -VDSwitch $MgmtVDSName -Name $VSANDVPGName -VlanId $ESXiVLAN -Confirm:$false | Out-Null


$vmhosts = Get-Cluster -Server $vc -Name $NewVCVSANClusterName | Get-VMHost
foreach ($vmhost in $vmhosts) {
	#Get-VDSwitch -Name $MgmtVDSName | Add-VDSwitchVMHost -VMHost $vmhost
	#$vmhostNetworkAdapter2 = Get-VMhost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic1
	#Get-VDSwitch -Name $MgmtVDSName | Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $vmhostNetworkAdapter2 -Confirm:$false | Out-Null

	#$dvportgroup = Get-VDPortgroup -name $MgmtDVPGName -VDSwitch $MgmtVDSName
	#$vmk = Get-VMHostNetworkAdapter -Name vmk0 -VMHost $vmhost
	#Set-VMHostNetworkAdapter -PortGroup $dvportgroup -VirtualNic $vmk -Confirm:$false | Out-Null

	#$vmhostNetworkAdapter1 = Get-VMHost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic0
	#Get-VDSwitch -Name $MgmtVDSName | Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $vmhostNetworkAdapter1 -Confirm:$false | Out-Null

    $vmk0 = Get-VMHostNetworkAdapter -Server $vc -Name vmk0 -VMHost $vmhost
    $vMotionlastNetworkOctetInt = [int]$vmk0.ip.Split('.')[-1] + 10
    $vMotionlastNetworkOctet = [string]$vMotionlastNetworkOctetInt
    $VSANlastNetworkOctetInt = [int]$vmk0.ip.Split('.')[-1] + 20
    $VSANlastNetworkOctet = [string]$VSANlastNetworkOctetInt
    $vMotionVmkIP = $NetworkSubnet + $vMotionlastNetworkOctet
    $VSANVmkIP = $NetworkSubnet + $VSANlastNetworkOctet

    #New-VMHostNetworkAdapter -VMHost $vmhost -PortGroup $vMotionDVPGName -VirtualSwitch $MgmtVDSName -IP $vMotionVmkIP -SubnetMask $VMNetmask -Mtu 1600 -VMotionEnabled:$true 
    New-VMHostNetworkAdapter -VMHost $vmhost -PortGroup $VSANDVPGName -VirtualSwitch $MgmtVDSName -IP $VSANVmkIP -SubnetMask $VMNetmask -Mtu 1600 -VMotionEnabled:$false -VsanTrafficEnabled:$true 

}

