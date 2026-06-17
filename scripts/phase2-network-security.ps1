<#
.SYNOPSIS
    Meridian Health Staffing Network Lab — Phase 2: Network Security
.DESCRIPTION
    Creates 6 NSGs (one per subnet requiring isolation), adds least-privilege
    inbound rules to each, and associates each NSG to its subnet. Clinical and
    workstation subnets in both clinics carry an explicit deny rule against
    the other clinic's address range as defense-in-depth, layered on top of
    the fact that no VNet peering exists between the two clinics at all.
.NOTES
    Author: Arielle Ezechukwu
    Project: Meridian Health Staffing Azure Networking Lab (AZ-104 portfolio)

    Two of these NSGs (nsg-clinicA-clinical, nsg-clinicA-workstation) were
    originally built by hand in the Azure portal as part of this lab's
    portal-vs-PowerShell practice split. Their rules are reproduced here in
    PowerShell form so this script is a complete, re-runnable record of the
    full Phase 2 build regardless of which interface was used originally.

    Valid NSG rule priorities are 100-4096. There is no valid priority below
    100 — this script reflects that correction.
#>

# ── Variables (re-set if starting a fresh session) ───────────────────────
$coreRG   = "rg-meridian-network-core"
$location = "eastus"

# ── Create NSGs ───────────────────────────────────────────────────────────
$nsgHubMgmt   = New-AzNetworkSecurityGroup -ResourceGroupName $coreRG -Location $location -Name "nsg-hub-management"
$nsgHubShared = New-AzNetworkSecurityGroup -ResourceGroupName $coreRG -Location $location -Name "nsg-hub-sharedservices"
$nsgAClin     = New-AzNetworkSecurityGroup -ResourceGroupName $coreRG -Location $location -Name "nsg-clinicA-clinical"
$nsgAWork     = New-AzNetworkSecurityGroup -ResourceGroupName $coreRG -Location $location -Name "nsg-clinicA-workstation"
$nsgBClin     = New-AzNetworkSecurityGroup -ResourceGroupName $coreRG -Location $location -Name "nsg-clinicB-clinical"
$nsgBWork     = New-AzNetworkSecurityGroup -ResourceGroupName $coreRG -Location $location -Name "nsg-clinicB-workstation"

# ── Rules: nsg-clinicA-clinical ───────────────────────────────────────────
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgAClin `
    -Name "Deny-ClinicB-Inbound" -Priority 100 -Direction Inbound -Access Deny `
    -Protocol * -SourceAddressPrefix "10.2.0.0/16" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange *

Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgAClin `
    -Name "Allow-SharedServices-Inbound" -Priority 110 -Direction Inbound -Access Allow `
    -Protocol * -SourceAddressPrefix "10.0.1.0/24" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange *

Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgAClin `
    -Name "Allow-RDP-FromManagement" -Priority 120 -Direction Inbound -Access Allow `
    -Protocol Tcp -SourceAddressPrefix "10.0.2.0/24" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389

$nsgAClin | Set-AzNetworkSecurityGroup

# ── Rules: nsg-clinicA-workstation ────────────────────────────────────────
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgAWork `
    -Name "Deny-ClinicB-Inbound" -Priority 100 -Direction Inbound -Access Deny `
    -Protocol * -SourceAddressPrefix "10.2.0.0/16" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange *

Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgAWork `
    -Name "Allow-SharedServices-Inbound" -Priority 110 -Direction Inbound -Access Allow `
    -Protocol * -SourceAddressPrefix "10.0.1.0/24" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange *

Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgAWork `
    -Name "Allow-RDP-FromManagement" -Priority 120 -Direction Inbound -Access Allow `
    -Protocol Tcp -SourceAddressPrefix "10.0.2.0/24" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389

$nsgAWork | Set-AzNetworkSecurityGroup

# ── Rules: nsg-clinicB-clinical ───────────────────────────────────────────
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgBClin `
    -Name "Deny-ClinicA-Inbound" -Priority 100 -Direction Inbound -Access Deny `
    -Protocol * -SourceAddressPrefix "10.1.0.0/16" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange *

Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgBClin `
    -Name "Allow-SharedServices-Inbound" -Priority 110 -Direction Inbound -Access Allow `
    -Protocol * -SourceAddressPrefix "10.0.1.0/24" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange *

Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgBClin `
    -Name "Allow-RDP-FromManagement" -Priority 120 -Direction Inbound -Access Allow `
    -Protocol Tcp -SourceAddressPrefix "10.0.2.0/24" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389

$nsgBClin | Set-AzNetworkSecurityGroup

# ── Rules: nsg-clinicB-workstation ────────────────────────────────────────
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgBWork `
    -Name "Deny-ClinicA-Inbound" -Priority 100 -Direction Inbound -Access Deny `
    -Protocol * -SourceAddressPrefix "10.1.0.0/16" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange *

Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgBWork `
    -Name "Allow-SharedServices-Inbound" -Priority 110 -Direction Inbound -Access Allow `
    -Protocol * -SourceAddressPrefix "10.0.1.0/24" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange *

Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgBWork `
    -Name "Allow-RDP-FromManagement" -Priority 120 -Direction Inbound -Access Allow `
    -Protocol Tcp -SourceAddressPrefix "10.0.2.0/24" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389

$nsgBWork | Set-AzNetworkSecurityGroup

# ── Rules: nsg-hub-sharedservices ─────────────────────────────────────────
# No deny rules here — shared services is meant to be reachable by both
# clinics, so there's nothing to wall off on this subnet.
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgHubShared `
    -Name "Allow-ClinicA-Inbound" -Priority 100 -Direction Inbound -Access Allow `
    -Protocol * -SourceAddressPrefix "10.1.0.0/16" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange *

Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgHubShared `
    -Name "Allow-ClinicB-Inbound" -Priority 110 -Direction Inbound -Access Allow `
    -Protocol * -SourceAddressPrefix "10.2.0.0/16" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange *

Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgHubShared `
    -Name "Allow-RDP-FromManagement" -Priority 120 -Direction Inbound -Access Allow `
    -Protocol Tcp -SourceAddressPrefix "10.0.2.0/24" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389

$nsgHubShared | Set-AzNetworkSecurityGroup

# ── Rules: nsg-hub-management ─────────────────────────────────────────────
# Allow-RDP-Internal is a DOCUMENTED LAB PLACEHOLDER. It uses the
# ManagementSubnet's own range as a stand-in for a real admin source.
# A production deployment would restrict this to a known, fixed admin IP
# range, or replace direct RDP exposure with Azure Bastion entirely.
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgHubMgmt `
    -Name "Allow-RDP-Internal" -Priority 100 -Direction Inbound -Access Allow `
    -Protocol Tcp -SourceAddressPrefix "10.0.2.0/24" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389

$nsgHubMgmt | Set-AzNetworkSecurityGroup

# ── Associate NSGs to subnets ─────────────────────────────────────────────
# Requires $hubVnet, $spokeAVnet, $spokeBVnet from Phase 1 to still be in
# session. If starting fresh, re-fetch them first:
#   $hubVnet    = Get-AzVirtualNetwork -ResourceGroupName $coreRG -Name "vnet-hub"
#   $spokeAVnet = Get-AzVirtualNetwork -ResourceGroupName $coreRG -Name "vnet-clinicA"
#   $spokeBVnet = Get-AzVirtualNetwork -ResourceGroupName $coreRG -Name "vnet-clinicB"

Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $spokeAVnet -Name "ClinicalSubnet" `
    -AddressPrefix "10.1.1.0/24" -NetworkSecurityGroup $nsgAClin

Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $spokeAVnet -Name "WorkstationSubnet" `
    -AddressPrefix "10.1.0.0/24" -NetworkSecurityGroup $nsgAWork

$spokeAVnet | Set-AzVirtualNetwork

Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $spokeBVnet -Name "ClinicalSubnet" `
    -AddressPrefix "10.2.1.0/24" -NetworkSecurityGroup $nsgBClin

Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $spokeBVnet -Name "WorkstationSubnet" `
    -AddressPrefix "10.2.0.0/24" -NetworkSecurityGroup $nsgBWork

$spokeBVnet | Set-AzVirtualNetwork

Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $hubVnet -Name "SharedServicesSubnet" `
    -AddressPrefix "10.0.1.0/24" -NetworkSecurityGroup $nsgHubShared

Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $hubVnet -Name "ManagementSubnet" `
    -AddressPrefix "10.0.2.0/24" -NetworkSecurityGroup $nsgHubMgmt

# NOTE: GatewaySubnet intentionally gets no NSG association — Azure does not
# permit attaching an NSG to a GatewaySubnet.

$hubVnet | Set-AzVirtualNetwork

# ── Verify: NSG-to-subnet associations, all VNets ────────────────────────
@("vnet-hub", "vnet-clinicA", "vnet-clinicB") | ForEach-Object {
    $vnetName = $_
    Get-AzVirtualNetwork -ResourceGroupName $coreRG -Name $vnetName |
        Select-Object -ExpandProperty Subnets |
        Select-Object @{N='VNet';E={$vnetName}}, Name, @{N='NSG';E={
            if ($_.NetworkSecurityGroup) { $_.NetworkSecurityGroup.Id -split '/' | Select-Object -Last 1 }
            else { '(none)' }
        }}
} | Format-Table -AutoSize

# ── Verify: full rule matrix across all 6 NSGs in one view ──────────────
@(
    @{VNet="vnet-hub"; Subnet="SharedServicesSubnet"; NSG="nsg-hub-sharedservices"},
    @{VNet="vnet-hub"; Subnet="ManagementSubnet"; NSG="nsg-hub-management"},
    @{VNet="vnet-clinicA"; Subnet="ClinicalSubnet"; NSG="nsg-clinicA-clinical"},
    @{VNet="vnet-clinicA"; Subnet="WorkstationSubnet"; NSG="nsg-clinicA-workstation"},
    @{VNet="vnet-clinicB"; Subnet="ClinicalSubnet"; NSG="nsg-clinicB-clinical"},
    @{VNet="vnet-clinicB"; Subnet="WorkstationSubnet"; NSG="nsg-clinicB-workstation"}
) | ForEach-Object {
    $entry = $_
    (Get-AzNetworkSecurityGroup -ResourceGroupName $coreRG -Name $entry.NSG).SecurityRules |
        Select-Object @{N='VNet';E={$entry.VNet}}, @{N='Subnet';E={$entry.Subnet}}, Name, Priority, Access, SourceAddressPrefix, DestinationPortRange
} | Format-Table -AutoSize

# Full rule documentation: see docs/nsg-matrix.md
