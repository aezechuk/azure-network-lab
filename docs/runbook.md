# Network Runbook — Meridian Health Staffing Network Lab

Operational reference for the hub-spoke network built in this lab: how it's structured, how to extend it, how to change it safely, and how to troubleshoot it when something doesn't work.

## 1. Environment overview

| Item | Value |
|---|---|
| Resource group | `rg-meridian-network-core` |
| Region | East US |
| Naming convention | `vnet-<name>`, `nsg-<scope>-<purpose>`, `rt-<scope>-<purpose>` |
| Tags applied to all resources | `Project=MeridianNetworkLab`, `Environment=Lab`, `Owner=Arielle.Ezechukwu` |

| VNet | Address space | Role |
|---|---|---|
| `vnet-hub` | 10.0.0.0/16 | Central hub — shared services, management, gateway |
| `vnet-clinicA` | 10.1.0.0/16 | Clinic A spoke (fully migrated to Azure) |
| `vnet-clinicB` | 10.2.0.0/16 | Clinic B spoke (fully migrated to Azure) |
| `vnet-onprem-sim` | 10.99.0.0/23 | Simulated on-premises clinic network |

Full subnet, NSG, and routing detail lives in `nsg-matrix.md` and `network-reference-matrix.md`.

## 2. Adding a new clinic site

To bring a new clinic site into this topology as a fully-migrated Azure spoke (the pattern used for Clinic A and B):

1. Create a new VNet with a non-overlapping address space (the next available block following the existing pattern would be `10.3.0.0/16`).
2. Add a `ClinicalSubnet` and `WorkstationSubnet`, following the same `/24` sizing used for Clinic A and B.
3. Create two NSGs (`-clinical`, `-workstation`) and apply the same rule pattern used for the existing clinics: explicit deny against every *other* clinic's address range, allow from `SharedServicesSubnet` (10.0.1.0/24), allow RDP only from `ManagementSubnet` (10.0.2.0/24).
4. Peer the new VNet to the hub in both directions (`Add-AzVirtualNetworkPeering`, run once from each side). Do **not** peer the new clinic to any existing clinic — spoke-to-spoke isolation is the standing design rule for this environment, not something specific to Clinic A and B.
5. Update `nsg-matrix.md` and `network-reference-matrix.md` with the new clinic's rules and routing.

If the new site is *not* migrating to Azure (still physically on-premises), follow the hybrid connectivity pattern in section 4 instead of peering.

## 3. Changing an NSG rule safely

1. Identify which NSG actually governs the subnet you're changing — check `nsg-matrix.md` first rather than guessing from the subnet name.
2. Use `Get-AzNetworkSecurityGroup` to fetch a **fresh** copy of the NSG object before editing. Stale local variables are the most common source of confusing errors in this environment (see section 6).
3. Add or modify the rule with `Add-AzNetworkSecurityRuleConfig` / `Set-AzNetworkSecurityRuleConfig` — use `Add-` for a rule that doesn't exist yet, `Set-` for editing an existing one by name. Valid priorities are 100–4096; there is no valid priority below 100.
4. Push the change with `<nsg-variable> | Set-AzNetworkSecurityGroup`.
5. Verify with `(Get-AzNetworkSecurityGroup ...).SecurityRules`, not the `.NetworkSecurityGroup.SecurityRules` path — confirm the exact property name for whichever cmdlet you're using, since `Get-AzNetworkSecurityGroup` and `Get-AzEffectiveNetworkSecurityGroup` expose rules under different property names (`SecurityRules` vs. `EffectiveSecurityRules`).
6. Update `nsg-matrix.md` to reflect the change.

## 4. Redeploying hybrid (VPN Gateway) connectivity

The VPN Gateway connecting the hub to `vnet-onprem-sim` was deployed, tested, and torn down within this lab. To redeploy it for a future demo or further testing:

1. **Budget time.** Each gateway takes 30–45 minutes to provision. Running both gateways in parallel (two terminal sessions) roughly halves total wait time.
2. **Use the current SKU.** Legacy `VpnGw1`–`VpnGw5` SKUs are deprecated. Use `VpnGw1AZ` (or higher) — Azure will reject the legacy SKU with `NonAzSkusNotAllowedForVPNGateway`.
3. **Zone-redundant public IPs are required for AZ SKUs.** Create public IPs with `-Sku Standard -AllocationMethod Static -Zone 1,2,3` before referencing them in the gateway IP config. A Standard SKU IP with no zones configured will be rejected with `VmssVpnGatewayPublicIpsMustHaveZonesConfigured`.
4. **Gateways must live in the same resource group as their VNet.** Azure enforces this; there is no way to put the gateway in a separate resource group from the VNet whose GatewaySubnet it occupies, even for teardown convenience. Plan accordingly rather than creating a dedicated VPN resource group.
5. **Create the connection in both directions** (`conn-hub-to-onprem` and `conn-onprem-to-hub`), using an identical shared key on both. Allow a few minutes after creation for `ConnectionStatus` to reach `Connected`.
6. **Test with real traffic, not just connection status.** A `Connected` status confirms the tunnel exists; it does not confirm packets actually flow. Ping between VMs on each side and check `IngressBytesTransferred` / `EgressBytesTransferred` on the connection object — both should be non-zero after a successful round trip.
7. **Expect to open ICMP at two separate layers if testing with ping**, on both the source and destination VM:
   - NSG rule allowing inbound traffic from the other side's address range (an on-prem/VPN source range is easy to miss if your NSGs were written assuming only Azure-native sources).
   - Windows Firewall on the guest OS itself, which blocks inbound ICMPv4 by default regardless of any NSG configuration. Run `New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 -Direction Inbound -Action Allow` on **both** the source and destination VM — a one-sided fix will show traffic crossing in one direction (visible as non-zero ingress at the gateway) but not the other (egress stuck at zero).
8. **For RDP access to test VMs with no public IP**, deploy Azure Bastion into each VNet that needs it. Bastion only provides access to VMs within its own VNet — a single Bastion deployment cannot reach across VNets, even peered ones. Bastion needs its own `/26`-or-larger subnet named exactly `AzureBastionSubnet`.
9. **Tear down the same session.** Gateways and Bastion both bill continuously while deployed. Delete connections first, then gateways, then Bastion, then any now-orphaned public IPs (deleting a gateway or Bastion does not automatically delete its public IP).

P2S (Point-to-Site) can run on the same gateway as S2S with no additional gateway cost — see the lab's Phase 4 documentation for the certificate generation and client installation steps. Note that P2S certificate authentication requires **two** certificates: a root certificate uploaded to the gateway, and a separate client certificate (signed by that root) installed locally. The root alone is not sufficient — Windows will fail to connect with Error 798 if only the root certificate exists.

## 5. Troubleshooting checklist

Work through these in order — each one rules out a layer before moving to the next:

1. **Peering status.** `Get-AzVirtualNetworkPeering` on both VNets in the relationship. Both sides must show `Connected`.
2. **NSG rules (configured, not effective).** `Get-AzNetworkSecurityGroup` on the relevant NSG — confirm the rule you expect actually exists, with the priority and source/destination you expect.
3. **NSG rules (effective).** `Get-AzEffectiveNetworkSecurityGroup` on the specific NIC — confirms what's actually being enforced, combining subnet and NIC-level rules with Azure's defaults. Requires a live VM with a NIC; cannot be checked on configuration alone.
4. **Route tables (effective).** `Get-AzEffectiveRouteTable` on the NIC — confirms whether a custom route is genuinely active, separate from whether anything is actually listening at its next hop.
5. **Guest OS firewall.** If NSGs and routes check out but traffic still fails, the guest OS itself (Windows Firewall, most commonly inbound ICMP) is the next most likely cause. This is invisible from any Azure-level command — it can only be checked by connecting into the VM itself.
6. **Gateway/connection status**, for anything crossing a VPN tunnel specifically. Check `ConnectionStatus` and the byte counters in both directions — a connection that's `Connected` but shows zero bytes in one direction usually points back to step 5 on the VM at that end.

## 6. Common PowerShell gotchas specific to this environment

- **Stale local variables.** `$hubVnet`, `$spokeAVnet`, and similar objects are snapshots fetched at a point in time — they do not stay in sync with Azure automatically. Re-fetch with `Get-AzVirtualNetwork` at the start of any new session, and again before any operation that depends on very recent changes (like a subnet just added).
- **Switch parameters don't take `$true`/`$false`.** Parameters like `-UseRemoteGateways` are switches — include the flag to mean "true," omit it entirely to mean "false." Passing `-UseRemoteGateways $false` throws "a positional parameter cannot be found that accepts argument 'False'."
- **NSG rule priority range is 100–4096.** There is no valid value below 100.
- **`Add-` vs `Set-` for NSG rules.** `Add-AzNetworkSecurityRuleConfig` is for rules that don't exist yet; `Set-AzNetworkSecurityRuleConfig` is for editing one that already does, by name. Using the wrong one throws either a duplicate-name error or "rule with the specified name does not exist."
- **VM size capacity errors are transient and size-specific**, not a sign anything is misconfigured. If a `New-AzVM` call fails with `SkuNotAvailable`, try a different size or VM family rather than retrying the same one repeatedly.
- **Bastion and VPN Gateway creation calls need a freshly-fetched VNet object.** Passing a stale VNet object to `New-AzBastion` or similar can fail with an opaque "value for reference id is missing" error even when the subnet genuinely exists.

---
*Meridian Health Staffing Network Lab · AZ-104 Portfolio Project*
