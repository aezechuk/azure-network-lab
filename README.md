# Azure Network Lab — Meridian Health Staffing

A hub-spoke network built end-to-end in Azure: segmented clinic sites, least-privilege NSGs, a documented (and intentionally non-functional) routing pattern for future traffic inspection, and hybrid connectivity proven two ways — site-to-site and point-to-site VPN.

## Business case

Meridian Health Staffing is expanding from a single Azure tenant into a multi-site clinical network. Two clinic locations need access to centralized shared services — but they should never be able to reach each other directly. A third site, still physically on-premises, needs to connect into the Azure environment the way a real branch office would: over the internet, through a VPN tunnel, not through a privileged shortcut.

This lab builds that network, tests it with real traffic, and documents every design decision.

## Architecture

A hub VNet holds shared services, an administrative subnet, and the VPN gateway endpoint. Two clinic VNets are peered to the hub — never to each other. A fourth VNet simulates the on-premises clinic site and connects to the hub exclusively through a VPN Gateway-to-Gateway tunnel.

Full address spacing, subnet breakdown, and the reasoning behind every NSG and routing decision live in [`docs/architecture.md`](./docs/architecture.md).

Clinic A reaches the hub, but cannot reach Clinic B — no path exists, reinforced by an explicit NSG deny as a second layer. The UDR pointing toward a future inspection point is confirmed live and active, and explicitly does not carry real traffic, since no firewall or NVA sits at its next hop yet. The VPN tunnel carried real ping traffic in both directions — site-to-site between the simulated on-prem site and the hub, and point-to-site from an actual laptop authenticated by certificate. Evidence for each is in [`docs/screenshots-index.md`](./docs/screenshots-index.md).
## How to build this

1. **Foundation** — resource group, four VNets, subnets, peering. No peering between the two clinic VNets, ever. → [`scripts/phase1-foundation.ps1`](./scripts/phase1-foundation.ps1)
2. **Network security** — six NSGs, least-privilege rules, RDP restricted to a single management range everywhere. → [`scripts/phase2-network-security.ps1`](./scripts/phase2-network-security.ps1)
3. **Routing** — a route table and UDR documenting the future-state inspection pattern, deliberately not backed by a deployed appliance.
4. **Hybrid connectivity** — VPN Gateway, S2S and P2S, deployed, tested with real traffic, torn down the same session.
5. **Validation** — four test VMs, allowed and denied paths both proven with live pings.

Step-by-step commands, the platform errors actually hit along the way (deprecated gateway SKUs, zone-redundant IP requirements, gateway/VNet resource group coupling, layered firewall blocks), and how each was resolved are in [`docs/runbook.md`](./docs/runbook.md).

## What I'd change for production

This lab made deliberate scope cuts to stay focused and cost-reasonable. None of them were accidents — here's what I'd do differently with a production budget and a real SLA:

- **Add Azure Firewall or an NVA at the hub.** The UDR already points at the correct next hop type (`VirtualAppliance`); production would actually deploy something there, enable IP forwarding, and add the Clinic A–Clinic B peering this lab deliberately omits.
- **Drop direct RDP entirely.** Every NSG in this build restricts RDP to a single subnet — but that subnet is a documented placeholder, not a real admin location. Azure Bastion was the actual access method used during testing; production should make that the only access method and remove the NSG allowance.
- **Keep the VPN Gateway running, properly.** This lab tears the gateway down after every test session to control cost. Production hybrid connectivity is a standing requirement, not a one-off — the gateway would stay up, sized for actual throughput needs, with monitoring and alerting on tunnel health.
- **Split resource groups by team ownership**, not just by lifecycle. This lab keeps everything in one resource group for simplicity. A real organization would likely separate network infrastructure from workload resources, governed by different teams with different change processes.
- **Move from manual builds to Infrastructure as Code.** Everything here was built by hand, deliberately, to understand every decision before automating it. The logical next step — already in progress — is re-expressing this same architecture in Bicep for repeatable, version-controlled deployment.

## Repo structure

```
azure-network-lab/
├── docs/              architecture, NSG matrix, routing decision memo,
│                       runbook, reference matrix, risk register, screenshot index
├── screenshots/        14 numbered screenshots, evidence for every major claim above
└── scripts/            final, re-runnable PowerShell for each phase
```

---
*Arielle Ezechukwu · Built as AZ-104 exam preparation and Cloud/SaaS Administrator portfolio work*
