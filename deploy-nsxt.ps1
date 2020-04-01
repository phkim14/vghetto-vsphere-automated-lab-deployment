$VMNetmask = "255.255.255.0"
$VMGateway = "192.168.30.1"
$VMDNS = "192.168.30.31"
$VMNTP = "192.168.30.31"
$VCSAIPAddress = "192.168.30.100"
$VCSAHostname = "pk-sitea-vcsa.pklab.local" #Change to IP if you don't have valid DNS
$VCSASSODomainName = "pklab.local"
$VCSASSOPassword = "VMware1!"
$MgmtDVPGName = "Management Network"
$NewVCDatacenterName = "Datacenter"
$NewVCVSANClusterName = "cluster-01"


#OVA
$NSXTManagerOVA = 'C:\Users\Administrator\Desktop\vsphere-lab-deploy\nsx-unified-appliance-2.5.1.0.0.15314292.ova'
$NSXTEdgeOVA = 'C:\Users\Administrator\Desktop\vsphere-lab-deploy\nsx-edge-2.5.1.0.0.15314297.ova'

# NSX-T Configuration
$DeployNSX = 1
$VSANdatastore = "vsanDatastore"
$NSXRootPassword = "VMware1!VMware1!"
$NSXAdminUsername = "admin"
$NSXAdminPassword = "VMware1!VMware1!"
$NSXAuditUsername = "audit"
$NSXAuditPassword = "VMware1!VMware1!"
$NSXSSHEnable = "true"
$NSXEnableRootLogin = "true" # this is required to be true for now until we have NSX-T APIs for initial setup
$NSXPrivatePortgroup = "dv-private-network"

$TunnelEndpointName = "SITEA-TEP-IP-Pool"
$TunnelEndpointDescription = "Tunnel Endpoint for Transport Nodes"
$TunnelEndpointIPRangeStart = "192.168.30.200"
$TunnelEndpointIPRangeEnd = "192.168.30.250"
$TunnelEndpointCIDR = "192.168.30.0/24"
$TunnelEndpointGateway = "192.168.30.1"

$OverlayTransportZoneName = "Overlay-TZ"
$VlanTransportZoneName = "VLAN-TZ"

$LogicalSwitchName = "Edge-Uplink"
$LogicalSwitchVlan = "3108"

$ESXiUplinkProfileName = "Sitea-ESXi-Uplink-Profile"
$ESXiUplinkProfilePolicy = "FAILOVER_ORDER" 
$ESXiUplinkProfileActivepNIC = "vmnic2" 
$ESXiUplinkProfileTransportVLAN = "0"
$ESXiUplinkProfileMTU = "1600"

$EdgeUplinkProfileName = "Sitea-Edge-Uplink-Profile"
$EdgeUplinkProfilePolicy = "FAILOVER_ORDER"
$EdgeUplinkProfileActivepNIC = "fp-eth1"
$EdgeUplinkProfileTransportVLAN = "0"
$EdgeUplinkProfileMTU = "1700"

$EdgeClusterName = "Sitea-Edge-Cluster-01"

# NSX-T Manager Configurations
$NSXTMgrDeploymentSize = "small"
$NSXTMgrvCPU = "4"
$NSXTMgrvMEM = "16" # GB
$NSXTMgrDisplayName = "nsxt-mgr-01"
$NSXTMgrHostname = "nsxt-mgr-01.pklab.local"
$NSXTMgrIPAddress = "192.168.30.151"

# NSX-T Edge Configuration
$NSXTEdgeDeploymentSize = "medium" # Use at least medium for LB POC
$NSXTEdgevCPU = "4"
$NSXTEdgevMEM = "8" # GB
$NSXTEdgeHostnameToIPs = @{
"sitea-edge-01" = "192.168.30.152"
}

$DeployNSXT = 0
$NSXTInitialConfig = 1

# Connect to VC
$vc = Connect-VIServer $VCSAIPAddress -User "administrator@$VCSASSODomainName" -Password $VCSASSOPassword -WarningAction SilentlyContinue

if($DeployNSXT -eq 1) {
    # Deploy NSX Manager
    $nsxMgrOvfConfig = Get-OvfConfiguration $NSXTManagerOVA
    $nsxMgrOvfConfig.DeploymentOption.Value = $NSXTMgrDeploymentSize
    $nsxMgrOvfConfig.NetworkMapping.Network_1.value = $MgmtDVPGName

    $nsxMgrOvfConfig.Common.nsx_role.Value = "NSX Manager"
    $nsxMgrOvfConfig.Common.nsx_hostname.Value = $NSXTMgrHostname
    $nsxMgrOvfConfig.Common.nsx_ip_0.Value = $NSXTMgrIPAddress
    $nsxMgrOvfConfig.Common.nsx_netmask_0.Value = $VMNetmask
    $nsxMgrOvfConfig.Common.nsx_gateway_0.Value = $VMGateway
    $nsxMgrOvfConfig.Common.nsx_dns1_0.Value = $VMDNS
    $nsxMgrOvfConfig.Common.nsx_domain_0.Value = $VMDomain
    $nsxMgrOvfConfig.Common.nsx_ntp_0.Value = $VMNTP

    if($NSXSSHEnable -eq "true") {
        $NSXSSHEnableVar = $true
    } else {
        $NSXSSHEnableVar = $false
    }
    $nsxMgrOvfConfig.Common.nsx_isSSHEnabled.Value = $NSXSSHEnableVar
    if($NSXEnableRootLogin -eq "true") {
        $NSXRootPasswordVar = $true
    } else {
        $NSXRootPasswordVar = $false
    }
    $nsxMgrOvfConfig.Common.nsx_allowSSHRootLogin.Value = $NSXRootPasswordVar

    $nsxMgrOvfConfig.Common.nsx_passwd_0.Value = $NSXRootPassword
    $nsxMgrOvfConfig.Common.nsx_cli_username.Value = $NSXAdminUsername
    $nsxMgrOvfConfig.Common.nsx_cli_passwd_0.Value = $NSXAdminPassword
    $nsxMgrOvfConfig.Common.nsx_cli_audit_username.Value = $NSXAuditUsername
    $nsxMgrOvfConfig.Common.nsx_cli_audit_passwd_0.Value = $NSXAuditPassword

    #My-Logger "Deploying NSX Manager VM $NSXTMgrDisplayName ..."
    $cluster = Get-Cluster -Server $vc -Name $NewVCVSANClusterName
    $vmhost = $cluster | Get-VMHost | Select -First 1
    $datastore = Get-Datastore -Server $vc -Name $VSANDatastore
    $nsxmgr_vm = Import-VApp -Server $vc -Source $NSXTManagerOVA -OvfConfiguration $nsxMgrOvfConfig -Name $NSXTMgrDisplayName -Location $cluster -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin

    #My-Logger "Updating vCPU Count to $NSXvCPU & vMEM to $NSXvMEM GB ..."
    #Set-VM -Server $viConnection -VM $nsxmgr_vm -NumCpu $NSXvCPU -MemoryGB $NSXvMEM -Confirm:$false 

    #My-Logger "Powering On $NSXTMgrDisplayName ..."
    $nsxmgr_vm | Start-Vm -RunAsync | Out-Null
}

if($NSXTInitialConfig -eq 1) {

    if(!(Connect-NsxtServer -Server $NSXTMgrHostname -Username $NSXAdminUsername -Password $NSXAdminPassword -WarningAction SilentlyContinue)) {
        Write-Host -ForegroundColor Red "Unable to connect to NSX Manager, please check the deployment"
        exit
    } else {
        Write-Host -ForegroundColor Green "Successfully logged into NSX Manager $NSXTMgrHostname  ..."
    }

    $runHealth=$true
    $runEULA=$false
    $runIPPool=$true
    $runTransportZone=$true
    $runAddVC=$true
    $runLogicalSwitch=$true
    $runHostPrep=$true
    $runUplinkProfile=$true
    $runAddESXiTransportNode=$true
    $runAddEdgeTransportNode=$true
    $runAddEdgeCluster=$true

    if($runEULA) {
        #My-Logger "Accepting NSX Manager EULA ..."
        $eulaService = Get-NsxtService -Name "com.vmware.nsx.eula.accept"
        $eulaService.create()
    }

    if($runAddVC) {
        #My-Logger "Adding vCenter Server Compute Manager ..."
        $computeManagerSerivce = Get-NsxtService -Name "com.vmware.nsx.fabric.compute_managers"
        $computeManagerStatusService = Get-NsxtService -Name "com.vmware.nsx.fabric.compute_managers.status"

        $computeManagerSpec = $computeManagerSerivce.help.create.compute_manager.Create()
        $credentialSpec = $computeManagerSerivce.help.create.compute_manager.credential.username_password_login_credential.Create()
        $VCUsername = "administrator@$VCSASSODomainName"
        $VCURL = "https://" + $VCSAHostname + ":443"
        $VCThumbprint = Get-SSLThumbprint256 -URL $VCURL
        $credentialSpec.username = $VCUsername
        $credentialSpec.password = $VCSASSOPassword
        $credentialSpec.thumbprint = $VCThumbprint
        $computeManagerSpec.server = $VCSAHostname
        $computeManagerSpec.origin_type = "vCenter"
        $computeManagerSpec.display_name = $VCSAHostname
        $computeManagerSpec.credential = $credentialSpec
        $computeManagerResult = $computeManagerSerivce.create($computeManagerSpec)
    }

}
