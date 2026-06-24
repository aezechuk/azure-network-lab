# Network Reference Matrix — Meridian Health Staffing Network Lab

The single table to check for "can subnet X reach subnet Y, and why or why not." Combines NSG rules (`nsg-matrix.md`), routing decisions (`routing-decision-memo.md`), and peering status into one reference. Pulled from the deployed environment in `rg-meridian-network-core`.

## Master reference table

| VNet | Subnet | NSG | Key allow/deny rules | Route table | Peering path to hub | Notes |
|---|---|---|---|---|---|---|
| vnet-hub | GatewaySubnet | *(none)* | N/A | N/A | N/A — hub itself | Reserved name; Azure does not permit NSGs here. VPN Gateway deployed here during Phase 4, torn down after testing. |
| vnet-hub | SharedServicesSubnet | nsg-hub-sharedservices | Allow Clinic A, Allow Clinic B, Allow RDP from management | None | N/A — hub itself | Hosts hub-vm. Deliberately has no deny rules — meant to be reachable by both clinics. |
| vnet-hub | ManagementSubnet | nsg-hub-management | Allow RDP, source is the subnet itself (documented placeholder) | None | N/A — hub itself | Represents where admin access originates. See risk-controls.md for the placeholder caveat. |
| vnet-clinicA | ClinicalSubnet | nsg-clinicA-clinical | Deny Clinic B, Allow shared services, Allow RDP from management | rt-clinicA-future-inspection | Connected (clinicA-to-hub / hub-to-clinicA) | Hosts clinicA-vm. Only subnet in the lab carrying a custom route table. |
| vnet-clinicA | WorkstationSubnet | nsg-clinicA-workstation | Deny Clinic B, Allow shared services, Allow RDP from management | None | Connected (same peering as ClinicalSubnet — peering is VNet-level, not subnet-level) | Lower-sensitivity traffic than ClinicalSubnet; rules kept consistent across both subnets by design choice. |
| vnet-clinicB | ClinicalSubnet | nsg-clinicB-clinical | Deny Clinic A, Allow shared services, Allow RDP from management | None | Connected (clinicB-to-hub / hub-to-clinicB) | Hosts clinicB-vm. Mirrors Clinic A's clinical subnet with source ranges swapped. |
| vnet-clinicB | WorkstationSubnet | nsg-clinicB-workstation | Deny Clinic A, Allow shared services, Allow RDP from management | None | Connected (same peering as ClinicalSubnet) | Mirrors Clinic A's workstation subnet. |
| vnet-onprem-sim | OnPremSubnet | *(none)* | N/A | None | **Not peered** — connects via VPN Gateway-to-Gateway only | Hosts onprem-sim-vm. Represents Clinic A's physical, non-Azure site. |
| vnet-onprem-sim | GatewaySubnet | *(none)* | N/A | N/A | N/A | Reserved name. VPN Gateway endpoint for the on-prem side of the S2S tunnel. |

## Reachability summary

| From | To | Reachable? | Why |
|---|---|---|---|
| Clinic A (either subnet) | Hub SharedServicesSubnet | Yes | Peered, and NSG explicitly allows it |
| Clinic B (either subnet) | Hub SharedServicesSubnet | Yes | Peered, and NSG explicitly allows it |
| Clinic A | Clinic B | **No** | No peering exists between the two spokes, *and* NSG explicit deny blocks it on both sides — enforced at two independent layers |
| Clinic B | Clinic A | **No** | Same as above, opposite direction |
| On-prem simulation | Hub SharedServicesSubnet | Conditional — only while VPN Gateway is deployed | No peering exists; only reachable via the S2S tunnel. Proven working in Phase 4, then gateway was torn down. Not reachable in the current (post-teardown) state of the environment. |
| Hub Management subnet | Any subnet, via RDP | Yes (RDP only, port 3389) | Every NSG in the lab explicitly allows RDP only from this subnet's range |
| Any subnet | Internet (inbound) | No | Azure's default deny-all-inbound-from-internet rule applies everywhere; nothing in this lab opens inbound internet access |

## Reading this table

A "Yes" in the reachability summary means both required conditions are met: a network path exists (peering or an active tunnel) **and** the NSG rules permit the traffic. Either condition failing alone is enough to block traffic — this lab deliberately uses both conditions together for the clinic-to-clinic boundary specifically, as defense-in-depth, while relying on path-only enforcement (no peering) elsewhere where a second layer wasn't judged necessary.

The route table column being mostly empty is intentional, not a gap. Only Clinic A's `ClinicalSubnet` carries a custom route, and even that route is explicitly documented as non-functional without a centralized inspection appliance — see `routing-decision-memo.md` for the full reasoning.

---
*Meridian Health Staffing Network Lab · AZ-104 Portfolio Project*
