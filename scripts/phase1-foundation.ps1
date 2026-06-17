<#
.SYNOPSIS
    Meridian Health Staffing Network Lab — Phase 1: Foundation & Topology
.DESCRIPTION
    Creates the core resource group, the four VNets (hub, Clinic A, Clinic B,
    on-prem simulation), their subnets, and peers the hub to each clinic spoke.
    No peering is created between Clinic A and Clinic B — that restriction is
    intentional and is the architectural decision this lab demonstrates.
.NOTES
    Author: Arielle Ezechukwu
    Project: Meridian Health Staffing Azure Networking Lab (AZ-104 portfolio)
#>

# ── Connect ───────────────────────────────────────────────────────────────
Connect-AzAccount
Get-AzContext

# ── Variables ─────────────────────────────────────────────────────────────
$location = "eastus"
$coreRG   = "rg-meridian-network-core"

# ── Resource Group ────────────────────────────────────────────────────────
New-AzResourceGroup -Name $coreRG -Location $location -Tag @{
    Project     = "MeridianNetworkLab"
    Environment = "Lab"
    Owner       = "Arielle.Ezechukwu"
    CostCenter  = "Portfolio"
}

# ── VNets ─────────────────────────────────────────────────────────────────
$hubVnet = New-AzVirtualNetwork -ResourceGroupName $coreRG -Location $location `
    -Name "vnet-hub" -AddressPrefix "10.0.0.0/16"

$spokeAVnet = New-AzVirtualNetwork -ResourceGroupName $coreRG -Location $location `
    -Name "vnet-clinicA" -AddressPrefix "10.1.0.0/16"

$spokeBVnet = New-AzVirtualNetwork -ResourceGroupName $coreRG -Location $location `
    -Name "vnet-clinicB" -AddressPrefix "10.2.0.0/16"

$onPremVnet = New-AzVirtualNetwork -ResourceGroupName $coreRG -Location $location `
    -Name "vnet-onprem-sim" -AddressPrefix "10.99.0.0/24"

# ── Subnets: Hub ──────────────────────────────────────────────────────────
Add-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $hubVnet `
    -AddressPrefix "10.0.0.0/27"

Add-AzVirtualNetworkSubnetConfig -Name "SharedServicesSubnet" -VirtualNetwork $hubVnet `
    -AddressPrefix "10.0.1.0/24"

Add-AzVirtualNetworkSubnetConfig -Name "ManagementSubnet" -VirtualNetwork $hubVnet `
    -AddressPrefix "10.0.2.0/24"

$hubVnet | Set-AzVirtualNetwork

# ── Subnets: Clinic A ─────────────────────────────────────────────────────
Add-AzVirtualNetworkSubnetConfig -Name "WorkstationSubnet" -VirtualNetwork $spokeAVnet `
    -AddressPrefix "10.1.0.0/24"

Add-AzVirtualNetworkSubnetConfig -Name "ClinicalSubnet" -VirtualNetwork $spokeAVnet `
    -AddressPrefix "10.1.1.0/24"

$spokeAVnet | Set-AzVirtualNetwork

# ── Subnets: Clinic B ─────────────────────────────────────────────────────
Add-AzVirtualNetworkSubnetConfig -Name "WorkstationSubnet" -VirtualNetwork $spokeBVnet `
    -AddressPrefix "10.2.0.0/24"

Add-AzVirtualNetworkSubnetConfig -Name "ClinicalSubnet" -VirtualNetwork $spokeBVnet `
    -AddressPrefix "10.2.1.0/24"

$spokeBVnet | Set-AzVirtualNetwork

# ── Subnets: On-Prem Simulation ───────────────────────────────────────────
# Gets its own GatewaySubnet too — Gateway-to-Gateway connections (Phase 4)
# require a gateway resource on both ends of the tunnel.
Add-AzVirtualNetworkSubnetConfig -Name "OnPremSubnet" -VirtualNetwork $onPremVnet `
    -AddressPrefix "10.99.0.0/25"

Add-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $onPremVnet `
    -AddressPrefix "10.99.0.128/27"

$onPremVnet | Set-AzVirtualNetwork

# ── Verify: all VNets, address spaces, and subnets in one view ──────────────
Get-AzVirtualNetwork -ResourceGroupName $coreRG | ForEach-Object {
    $vnetName = $_.Name
    $addressSpace = $_.AddressSpace.AddressPrefixes -join ", "
    $_.Subnets | Select-Object @{N='VNet';E={$vnetName}}, @{N='VNetAddressSpace';E={$addressSpace}}, Name, AddressPrefix
} | Format-Table -AutoSize

# ── Peering: Hub <-> Clinic A ─────────────────────────────────────────────
# AllowGatewayTransit on the hub side lets spokes use the hub's VPN Gateway
# (built in Phase 4) to reach the on-prem simulation network.
Add-AzVirtualNetworkPeering -Name "hub-to-clinicA" `
    -VirtualNetwork $hubVnet `
    -RemoteVirtualNetworkId $spokeAVnet.Id `
    -AllowForwardedTraffic `
    -AllowGatewayTransit

# UseRemoteGateways is a switch parameter — it cannot take $true/$false.
# Omitting it leaves it at its default (false), which is what we want here.
Add-AzVirtualNetworkPeering -Name "clinicA-to-hub" `
    -VirtualNetwork $spokeAVnet `
    -RemoteVirtualNetworkId $hubVnet.Id `
    -AllowForwardedTraffic

# ── Peering: Hub <-> Clinic B ─────────────────────────────────────────────
Add-AzVirtualNetworkPeering -Name "hub-to-clinicB" `
    -VirtualNetwork $hubVnet `
    -RemoteVirtualNetworkId $spokeBVnet.Id `
    -AllowForwardedTraffic `
    -AllowGatewayTransit

Add-AzVirtualNetworkPeering -Name "clinicB-to-hub" `
    -VirtualNetwork $spokeBVnet `
    -RemoteVirtualNetworkId $hubVnet.Id `
    -AllowForwardedTraffic

# NOTE: No peering is created between vnet-clinicA and vnet-clinicB.
# This is intentional. Clinic-to-clinic isolation is the core architectural
# decision this lab demonstrates — see docs/architecture.md and
# docs/routing-decision-memo.md.

# NOTE: vnet-onprem-sim is NOT peered to the hub. It connects via a VPN
# Gateway-to-Gateway connection in Phase 4, simulating a real on-premises
# site connecting over an IPsec/IKE tunnel rather than native Azure peering.

# ── Verify: peering status across all VNets ──────────────────────────────
@("vnet-hub", "vnet-clinicA", "vnet-clinicB") | ForEach-Object {
    $vnetName = $_
    Get-AzVirtualNetworkPeering -ResourceGroupName $coreRG -VirtualNetworkName $vnetName |
        Select-Object @{N='VNet';E={$vnetName}}, Name, PeeringState, AllowForwardedTraffic, AllowGatewayTransit
} | Format-Table -AutoSize

# Expect: 4 peerings, all PeeringState = Connected.
# hub-to-clinicA / hub-to-clinicB should show AllowGatewayTransit = True.
