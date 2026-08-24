# routeros documentation

routeros is a thick, friendly layer over the MikroTik RouterOS API for
the [Jennifer](https://jennifer-lang.dev/) language. Each guide below
covers one topic file of the module with background, the full function
surface, worked examples, and the pitfalls the abstraction protects you
from.

## Conventions used in every guide

All snippets assume an established connection:

```jennifer
import "./routeros.j" as mt;

def c as mt.Client init mt.connect("192.168.88.1", "admin", "secret");
# ... snippets go here ...
mt.disconnect($c);
```

Errors: every validation failure raised by routeros is an
`Error{kind: "routeros"}` with a human-readable message; errors coming
from the router or the wire are `Error{kind: "mikrotik"}`. Catch either
with `try { ... } catch (e) { io.printf("%s\n", $e.message); }`.

Verbose mode: `$c = mt.setVerbose($c, true);` prints every command the
client sends to stdout (`mt> /ip/address/add address=... interface=...`),
with credentials redacted — see [core.md](core.md). It returns a copy, so
keep the returned client. `MT_VERBOSE=1` in the environment turns it on
at `connect` time without touching the script.

Ids: RouterOS gives every list item an internal id like `"*3"`. The
`add*` functions return it, the typed structs carry it in `.id`, and the
generic verbs accept it. Most routeros helpers let you use a *name* or
a *comment* instead, so you rarely touch ids directly.

The condensed, everything-on-one-page reference is
[cheatsheet.md](cheatsheet.md). For the RouterOS side itself -
every menu, property, and behavior these topics wrap - see MikroTik's
official [RouterOS documentation](https://help.mikrotik.com/docs/).

## Guides

| Guide | Covers |
|---|---|
| [cheatsheet.md](cheatsheet.md) | **the whole API surface on one page** |
| [core.md](core.md) | connecting, the generic add/set/remove verbs, shared validation |
| [interfaces.md](interfaces.md) | listing, enabling, renaming physical and virtual interfaces |
| [interfacelist.md](interfacelist.md) | interface lists: WAN/LAN groups for firewall matching |
| [lte.md](lte.md) | LTE / cellular uplink: signal, APN, backup WAN |
| [ethernet.md](ethernet.md) | port settings: speed, duplex, MTU, PoE, link state |
| [bonding.md](bonding.md) | link aggregation: LACP trunks, failover bundles |
| [bridges.md](bridges.md) | bridges and bridge ports (virtual switches) |
| [switch.md](switch.md) | switch chip: hardware offload inventory and verification |
| [vlans.md](vlans.md) | 802.1Q tagged interfaces |
| [firewall.md](firewall.md) | filter rules: the builder, comment handles, shortcuts |
| [nat.md](nat.md) | masquerade and port forwarding |
| [upnp.md](upnp.md) | UPnP: LAN devices open their own port forwards |
| [trafficflow.md](trafficflow.md) | NetFlow / IPFIX export to a collector |
| [raw.md](raw.md) | firewall raw: pre-conntrack drop / notrack |
| [addresslist.md](addresslist.md) | firewall address lists: one rule, living list |
| [mangle.md](mangle.md) | packet marking: queue marks, policy routing, MSS clamp |
| [contrack.md](contrack.md) | connection tracking: the live connection table |
| [ip.md](ip.md) | IP addresses on interfaces |
| [ipv6.md](ipv6.md) | IPv6: the stack switch, addresses, router advertisements |
| [arp.md](arp.md) | the ARP table: who is on the LAN, pinned bindings |
| [neighbor.md](neighbor.md) | neighbor discovery: what is on this segment (LLDP/CDP/MNDP) |
| [dhcp.md](dhcp.md) | DHCP server, leases, and the WAN-side DHCP client |
| [ppp.md](ppp.md) | PPPoE dial-in WAN (DSL/fiber) |
| [hotspot.md](hotspot.md) | the captive guest portal: vouchers, bypass, walled garden |
| [vpn.md](vpn.md) | remote-access VPN: L2TP, SSTP, OpenVPN, IKEv2, PPP users |
| [dns.md](dns.md) | resolver settings and static DNS entries |
| [routing.md](routing.md) | static routes and the default route |
| [queues.md](queues.md) | bandwidth limiting with simple queues |
| [wireless.md](wireless.md) | WiFi: SSIDs, passwords, guest networks, clients (classic menu) |
| [wifi.md](wifi.md) | modern WiFi (wifiwave2/ax, RouterOS v7) |
| [wireguard.md](wireguard.md) | WireGuard VPN tunnels (RouterOS v7) |
| [eoip.md](eoip.md) | EoIP: one LAN across two sites |
| [gre.md](gre.md) | GRE: routed site-to-site links, any vendor |
| [ipsec.md](ipsec.md) | IPsec: standards-based site-to-site, multi-vendor |
| [vrrp.md](vrrp.md) | VRRP: two routers, one gateway, automatic failover |
| [tools.md](tools.md) | ping, bandwidth test, fetch, e-mail alerting |
| [sms.md](sms.md) | text messages over the cellular modem |
| [netwatch.md](netwatch.md) | continuous host monitoring with on-change scripts |
| [scheduler.md](scheduler.md) | scripts on a timer |
| [script.md](script.md) | the stored-script repository (run by name) |
| [users.md](users.md) | router accounts, groups, active sessions |
| [services.md](services.md) | management services: hardening the ways in |
| [certificates.md](certificates.md) | TLS: self-signed, Let's Encrypt, the acme flow |
| [clock.md](clock.md) | clock and NTP: a router that knows what time it is |
| [files.md](files.md) | files and configuration backups |
| [disk.md](disk.md) | storage devices: list, format, eject |
| [cloud.md](cloud.md) | MikroTik Cloud DDNS: a stable name for a dynamic WAN |
| [snmp.md](snmp.md) | SNMP: plug the router into monitoring |
| [radius.md](radius.md) | RADIUS: central authentication for logins/VPN/hotspot |
| [health.md](health.md) | system health: temperature, voltage, fans |
| [container.md](container.md) | run OCI containers on the router (v7) |
| [capsman.md](capsman.md) | CAPsMAN: central management of many access points |
| [log.md](log.md) | reading the router log, routing what gets logged |
| [system.md](system.md) | packages, updates, firmware, reboot |

One runnable example per topic lives in [`../examples/`](../examples/)
(`MT_HOST=... MT_USER=... MT_PASSWORD=... jennifer run examples/<topic>.j`).

## Disclaimer

MikroTik and RouterOS are trademarks of SIA Mikrotīkls. routeros is an
independent, community-written client library, **not affiliated with,
endorsed, or supported by SIA Mikrotīkls** — and it configures live
network equipment. **Use at your own risk**; no warranty of any kind.

Licensed under the **GNU LGPL v3.0 only** — see
[../LICENSE.md](../LICENSE.md).

## Running the tests

```sh
jennifer test src/routeros_test.j
```

The white-box overlay exercises everything network-free: validators,
row folding, builders, and normalization. Functions that need a live
router are thin compositions of those tested helpers.
