# Architecture — Meridian Health Staffing Network Lab

<img width="1280" height="816" alt="architecture" src="https://github.com/user-attachments/assets/7d8b0371-f1cf-43dd-b814-b78311871a27" />

## Overview

This lab builds a hub-spoke network for Meridian Health Staffing, a fictional multi-site clinical organization expanding from a single Azure tenant into a network connecting two clinic locations to centralized shared services. The design also simulates hybrid connectivity between an on-premises clinic network and the Azure hub using a site-to-site VPN pattern.

All resources live in a single resource group, `rg-meridian-network-core`, in East US.

## Topology

**Hub VNet** (`vnet-hub`, 10.0.0.0/16) is the central network every other VNet connects to. It holds three subnets: `GatewaySubnet` (10.0.0.0/27), reserved for the VPN Gateway used during hybrid connectivity testing; `SharedServicesSubnet` (10.0.1.0/24), home to `hub-vm` and representing infrastructure both clinics depend on; and `ManagementSubnet` (10.0.2.0/24), representing where administrative RDP access originates from.

**Clinic A** (`vnet-clinicA`, 10.1.0.0/16) and **Clinic B** (`vnet-clinicB`, 10.2.0.0/16) are spoke VNets representing two physical clinic sites that have fully migrated to Azure. Each is split into a `ClinicalSubnet`, holding the more sensitive clinical workload VM, and a `WorkstationSubnet`, holding general staff workstation traffic. Both spokes are peered directly to the hub.

**On-premises simulation** (`vnet-onprem-sim`, 10.99.0.0/23) represents a clinic site that has *not* migrated to Azure, a physical office with its own local network. It connects to the hub over a VPN Gateway-to-Gateway tunnel rather than native VNet peering, the same IPsec/IKE mechanism a real on-premises router would use to connect over the public internet. This distinction is deliberate: peering would have made the connection trivial and wouldn't demonstrate hybrid connectivity at all.

## The core design decision: no clinic-to-clinic path

Clinic A and Clinic B are never peered to each other. This is the architectural decision this lab is built around, not an oversight. If Clinic A and Clinic B ever needed to communicate, the design calls for that traffic to route through a centralized inspection point in the hub (a firewall or NVA), never directly between spokes.

That isolation is enforced at two independent layers, not one. No VNet peering exists between the two clinics, so no network path connects them today, full stop. On top of that, explicit NSG deny rules on both clinics' subnets block traffic from the other clinic's address range, so if a peering connection were ever added later, intentionally or by mistake, the NSG rules would still hold the line. See `nsg-matrix.md` for the full rule set.

A route table (`rt-clinicA-future-inspection`) documents the intended future-state pattern: a UDR pointing Clinic A's traffic for Clinic B's range at a `VirtualAppliance` next hop in the hub. No firewall or NVA exists at that address today, so the route is real and active but doesn't carry functional traffic, it's a documented design intent, not a working path. The full reasoning for deferring Azure Firewall and NVA deployment is in `routing-decision-memo.md`.

## Hybrid connectivity

A VPN Gateway was deployed in the hub and connected Gateway-to-Gateway with `vnet-onprem-sim`, simulating Clinic A's physical office connecting to Azure over the internet. Connectivity was tested and proven in both directions with real traffic: `onprem-sim-vm` successfully pinged `hub-vm` across the tunnel, and a Point-to-Site VPN was additionally configured and tested, allowing a remote administrator's laptop to connect directly into the hub network and reach `hub-vm`, all authenticated via certificate rather than username and password.

Because VPN Gateways bill continuously while deployed, both the gateways and their associated Azure Bastion resources (used for RDP access into the VMs during testing) were torn down in the same session once connectivity was validated and evidence was captured. The diagram shows this tunnel as a designed connection point; it is not currently deployed in the live environment. Anyone redeploying it should expect 30–45 minutes of provisioning time per gateway and should budget for the gateway SKU consolidation behavior noted in `runbook.md` (legacy `VpnGwN` SKUs are deprecated in favor of `VpnGwNAZ`, which require zone-redundant public IPs).

## What's deliberately not here

No Azure Firewall, no NVA, and no functioning spoke-to-spoke path. Each of these was evaluated and explicitly deferred, not missed, for reasons documented in `routing-decision-memo.md`. The lab prioritizes demonstrating NSG- and UDR-based segmentation, the core AZ-104 networking competencies, over deploying production-grade traffic inspection that the lab's scope didn't require.

---

*Meridian Health Staffing Network Lab · AZ-104 Portfolio Project*

