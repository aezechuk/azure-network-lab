# Routing & Centralized Inspection Decision Memo

**Project:** Meridian Health Staffing Network Lab
**Phase:** 3 — Routing
**Decision:** Centralized inspection (Azure Firewall or NVA) evaluated and deferred for this lab. NSG and UDR-based segmentation selected for hands-on implementation.

## Context

The hub-spoke topology connects two clinic sites (Clinic A, Clinic B) to a central hub, with no direct peering between the two clinics. This is an intentional isolation boundary: clinic-to-clinic traffic should never flow directly, and if it's ever needed, it should be routed through a centralized inspection point in the hub first.

Three options were evaluated for what that centralized inspection point would be.

## Options Evaluated

| Option | What it offers | Decision |
|---|---|---|
| **Azure Firewall** | Centralized L3–L7 inspection, threat intelligence feeds, fully managed by Microsoft, no OS-level configuration required | **Deferred.** Runs roughly $1.25/hr or more plus data processing charges, billed continuously regardless of traffic. Provisioning is slow. Cost and complexity are not justified for a lab whose primary goal is demonstrating routing and segmentation mechanics, not running production-grade traffic inspection. |
| **Third-party NVA (VM-based)** | Lower raw compute cost than Azure Firewall, full control over routing and inspection logic | **Deferred.** Requires enabling IP forwarding at both the Azure NIC level and inside the guest OS, plus vendor-specific configuration (or hand-rolled iptables/routing rules). This work sits closer to AZ-700 (Networking specialty) scope than AZ-104, and the configuration overhead would consume hours without reinforcing core AZ-104 competencies. |
| **NSG + UDR only** | No additional cost, native to subnet/VNet configuration, demonstrates the foundational mechanics AZ-104 actually tests | **Selected.** Implemented in this lab. |

## What Was Implemented

A route table (`rt-clinicA-future-inspection`) was created and associated to Clinic A's `ClinicalSubnet`. It contains one custom route:

- **Address prefix:** `10.2.0.0/16` (Clinic B's range)
- **Next hop type:** `VirtualAppliance`
- **Next hop IP:** `10.0.1.4` (an unused address in the hub's `SharedServicesSubnet`)

This route was confirmed live and `Active` via `Get-AzEffectiveRouteTable` once a test VM existed on the subnet.

## Important Technical Clarification

**This UDR does not enable functional spoke-to-spoke traffic today.** VNet peering alone does not forward traffic between spokes, and a UDR alone doesn't either, unless something at the specified next hop is actually capable of receiving and forwarding traffic. No firewall or NVA exists at `10.0.1.4`. The route is real and correctly propagated, but nothing is listening at that address.

The accurate way to describe the current state: Clinic A and Clinic B have no functional path to reach each other, by design, enforced at two independent layers — no VNet peering exists between them, and explicit NSG deny rules block traffic from the other clinic's address range on both clinics' subnets (see `docs/nsg-matrix.md`). The UDR documents the intended future-state routing pattern: if centralized inspection is ever implemented, traffic would be routed through the hub via `NextHopType: VirtualAppliance`, the correct Azure construct for an NVA or firewall scenario, rather than directly between spokes.

## If This Were Revisited for Production

A production deployment of this architecture would likely choose Azure Firewall over a self-managed NVA, trading the higher hourly cost for reduced operational overhead, managed threat intelligence, and tighter integration with Azure Monitor and other Microsoft security tooling. The decision to defer it here is specific to lab cost and AZ-104 exam scope, not a recommendation against centralized inspection in general — quite the opposite, this lab's design explicitly reserves the routing pattern (`VirtualAppliance` next hop) needed to add one later with minimal rework: deploy the appliance at `10.0.1.4`, enable IP forwarding, add the mirrored UDR on Clinic B's subnet, and add Clinic A–Clinic B peering so there's traffic to inspect in the first place.

---
*Meridian Health Staffing Network Lab · AZ-104 Portfolio Project*
