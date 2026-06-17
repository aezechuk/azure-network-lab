# NSG Rule Matrix — Meridian Health Staffing Network Lab

This table documents every Network Security Group (NSG) in the Meridian hub-spoke network, the subnet it's attached to, and every inbound rule configured on it. Pulled directly from the deployed environment in `rg-meridian-network-core`.

## Hub VNet (vnet-hub, 10.0.0.0/16)

| Subnet | NSG | Rule Name | Priority | Access | Source | Destination Port | Purpose |
|---|---|---|---|---|---|---|---|
| SharedServicesSubnet | nsg-hub-sharedservices | Allow-ClinicA-Inbound | 100 | Allow | 10.1.0.0/16 | * | Clinic A reaches shared services |
| SharedServicesSubnet | nsg-hub-sharedservices | Allow-ClinicB-Inbound | 110 | Allow | 10.2.0.0/16 | * | Clinic B reaches shared services |
| SharedServicesSubnet | nsg-hub-sharedservices | Allow-RDP-FromManagement | 120 | Allow | 10.0.2.0/24 | 3389 | Admin RDP into hub-vm |
| ManagementSubnet | nsg-hub-management | Allow-RDP-Internal | 100 | Allow | 10.0.2.0/24 | 3389 | Placeholder: documented lab simplification — production would restrict to known admin IP ranges or use Azure Bastion instead of direct RDP |
| GatewaySubnet | *(none — Azure does not permit NSGs on GatewaySubnet)* | — | — | — | — | — | Reserved for VPN Gateway |

## Clinic A VNet (vnet-clinicA, 10.1.0.0/16)

| Subnet | NSG | Rule Name | Priority | Access | Source | Destination Port | Purpose |
|---|---|---|---|---|---|---|---|
| ClinicalSubnet | nsg-clinicA-clinical | Deny-ClinicB-Inbound | 100 | Deny | 10.2.0.0/16 | * | Defense-in-depth: explicit block on Clinic B traffic even though no peering exists |
| ClinicalSubnet | nsg-clinicA-clinical | Allow-SharedServices-Inbound | 110 | Allow | 10.0.1.0/24 | * | Clinical workloads reach shared services |
| ClinicalSubnet | nsg-clinicA-clinical | Allow-RDP-FromManagement | 120 | Allow | 10.0.2.0/24 | 3389 | Admin RDP into clinicA-vm |
| WorkstationSubnet | nsg-clinicA-workstation | Deny-ClinicB-Inbound | 100 | Deny | 10.2.0.0/16 | * | Defense-in-depth, consistent with clinical subnet |
| WorkstationSubnet | nsg-clinicA-workstation | Allow-SharedServices-Inbound | 110 | Allow | 10.0.1.0/24 | * | Workstation traffic reaches shared services |
| WorkstationSubnet | nsg-clinicA-workstation | Allow-RDP-FromManagement | 120 | Allow | 10.0.2.0/24 | 3389 | Admin RDP access |

## Clinic B VNet (vnet-clinicB, 10.2.0.0/16)

| Subnet | NSG | Rule Name | Priority | Access | Source | Destination Port | Purpose |
|---|---|---|---|---|---|---|---|
| ClinicalSubnet | nsg-clinicB-clinical | Deny-ClinicA-Inbound | 100 | Deny | 10.1.0.0/16 | * | Defense-in-depth: explicit block on Clinic A traffic even though no peering exists |
| ClinicalSubnet | nsg-clinicB-clinical | Allow-SharedServices-Inbound | 110 | Allow | 10.0.1.0/24 | * | Clinical workloads reach shared services |
| ClinicalSubnet | nsg-clinicB-clinical | Allow-RDP-FromManagement | 120 | Allow | 10.0.2.0/24 | 3389 | Admin RDP into clinicB-vm |
| WorkstationSubnet | nsg-clinicB-workstation | Deny-ClinicA-Inbound | 100 | Deny | 10.1.0.0/16 | * | Defense-in-depth, consistent with clinical subnet |
| WorkstationSubnet | nsg-clinicB-workstation | Allow-SharedServices-Inbound | 110 | Allow | 10.0.1.0/24 | * | Workstation traffic reaches shared services |
| WorkstationSubnet | nsg-clinicB-workstation | Allow-RDP-FromManagement | 120 | Allow | 10.0.2.0/24 | 3389 | Admin RDP access |

## On-Prem Simulation VNet (vnet-onprem-sim, 10.99.0.0/24)

| Subnet | NSG | Notes |
|---|---|---|
| OnPremSubnet | *(none configured)* | Represents Clinic A's on-premises network; reachable only via VPN Gateway-to-Gateway connection, built in Phase 4 |
| GatewaySubnet | *(none — Azure does not permit NSGs on GatewaySubnet)* | Reserved for VPN Gateway |

## Design Notes

**Clinic-to-clinic isolation is enforced at two independent layers.** No VNet peering exists between vnet-clinicA and vnet-clinicB, so no network path connects them today. The explicit Deny rules on both clinics' subnets are a second, independent layer of defense-in-depth: if a future peering connection were ever added between the clinics, intentionally or by mistake, these NSG rules would still block the traffic.

**RDP exposure is deliberately limited.** Every RDP allow rule across all subnets restricts the source to the hub's ManagementSubnet (10.0.2.0/24) only. No subnet allows RDP from the public internet.

**The ManagementSubnet's own RDP rule is a documented placeholder.** `Allow-RDP-Internal` on nsg-hub-management uses the subnet's own range as a stand-in for a real admin source (a fixed office IP, VPN range, or jump box). This is a deliberate lab simplification, not a production-ready pattern. A real deployment would either restrict this to a known, fixed admin IP range or replace direct RDP exposure with Azure Bastion.

**GatewaySubnets carry no NSG.** Azure does not permit attaching an NSG to a GatewaySubnet — this applies to both the hub's GatewaySubnet and the on-prem simulation VNet's GatewaySubnet.

---
*Meridian Health Staffing Network Lab · AZ-104 Portfolio Project*
