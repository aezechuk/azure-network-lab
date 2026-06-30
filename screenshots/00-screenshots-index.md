# Screenshot Index — Meridian Health Staffing Network Lab
 
All evidence captured during the build, organized by phase and what each one proves.
 
| # | Filename | Phase | What it shows |
|---|---|---|---|
| 01 | `01-az-context.png` | 1 | `Get-AzContext` output confirming the correct Azure subscription before any resources were created |
| 02 | `02-vnets-overview.png` | 1 | All 4 VNets with their address spaces and full subnet list, pulled in one PowerShell rollup |
| 03 | `03-peering-status.png` | 1 | All 4 peering connections (hub-to-clinicA, clinicA-to-hub, hub-to-clinicB, clinicB-to-hub) confirmed `Connected` |
| 04 | `04-nsg-subnet-associations.png` | 2 | Each subnet's associated NSG, confirming all 6 NSGs landed on the correct subnet and GatewaySubnet correctly has none |
| 05 | `05-effective-security-rules.png` | 2 | `Get-AzEffectiveNetworkSecurityGroup` output on `clinicA-vm-nic`, filtered to custom rules only — proves the NSG rules are genuinely effective on a live NIC, not just configured |
| 06 | `06-route-table-association.png` | 3 | `rt-clinicA-future-inspection` confirmed associated to `ClinicalSubnet` (and explicitly *not* associated to `WorkstationSubnet`) |
| 07 | `07-effective-route-active.png` | 3 | `Get-AzEffectiveRouteTable` confirming the custom UDR is `Active` with `NextHopType: VirtualAppliance` — proves the route is genuinely live, independent of whether anything is listening at the next hop |
| 08 | `08-vpn-gateways-provisioned.png` | 4 | Both VPN gateways (`vpngw-hub`, `vpngw-onprem`) showing `Succeeded` provisioning state, deployed on the current `VpnGw1AZ` SKU with zone-redundant public IPs |
| 09 | `09-vpn-connection-status.png` | 4 | Gateway-to-Gateway connection (`conn-hub-to-onprem`) showing `Connected`, with byte counters as the baseline before traffic testing |
| 10 | `10-vpn-ping-success.png` | 4 | Successful ping from `onprem-sim-vm` to `hub-vm` across the S2S tunnel — 0% packet loss, real round-trip times, proving the hybrid connectivity path actually carries traffic |
| 11 | `11-p2s-configuration.png` | 4 (optional, completed) | Windows VPN settings showing the P2S connection `Connected`, alongside a successful 4/4 ping from the local laptop into the hub — proves certificate-based P2S authentication and connectivity end to end |
| 12 | `12-vms-running.png` | 5 | All 4 test VMs (`hub-vm`, `clinicA-vm`, `clinicB-vm`, `onprem-sim-vm`) confirmed `Running` |
| 13 | `13-allowed-path-clinicA-to-hub.png` | 5 | Successful ping from `clinicA-vm` to `hub-vm` — proves VNet peering and NSG rules correctly allow this path |
| 14 | `14-denied-path-clinicA-to-clinicB.png` | 5 | Failed ping from `clinicA-vm` to `clinicB-vm` — the single most important screenshot in the project, proving clinic-to-clinic isolation holds with zero peering and explicit NSG denies both in effect |
