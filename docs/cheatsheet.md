# routeros cheatsheet

The full API surface of the routeros module in one place, plus the
project layout, test instructions, and requirements. Background and
worked examples per topic live in the guides indexed in
[README.md](README.md); runnable per-topic examples are in
[../examples/](../examples/).

All snippets assume an established connection:

```jennifer
import "./src/routeros.j" as mt;
def c as mt.Client init mt.connect("192.168.88.1", "admin", "secret");
```

## API surface

**Connecting** — `connect(host, user, password)`,
`connectTLS(host, user, password)`,
`connectWith(host, port, user, password, tls)` → `Client`;
`disconnect(c)`.

**Generic verbs** (any RouterOS list path, e.g. `"/ip/address"`) —
`getAll(c, path)`, `add(c, path, attrs)` → id, `set(c, path, id, attrs)`,
`update` (synonym of `set`), `remove(c, path, id)` (RouterOS's delete),
`removeByName(c, path, name)`, `findByName(c, path, name)`,
`idByName(c, path, name)`, `enable(c, path, id)`, `disable(c, path, id)`.

**Interfaces** — `interfaces(c)` → `list of Interface`,
`interfaceByName(c, name)`, `enableInterface` / `disableInterface(c, name)`,
`renameInterface(c, current, next)`, `commentInterface(c, name, comment)`.

**Ethernet ports** — the physical layer: `ethernetPorts(c)` →
`list of EthernetPort` (settings, PoE mode, bridge-slave flag),
`ethernetPortByName(c, name)`, and the live measurement
`linkStatus(c, name)` → `LinkStatus` (`up`, negotiated `rate`,
`fullDuplex` — the first check when "the network is slow").
`forceEthernetLink(c, name, speed, fullDuplex)` pins speed/duplex for
stubborn link partners (both ends must match — the docblock explains
the duplex-mismatch trap), `autoNegotiateEthernet(c, name)` restores
the default, `setEthernetMtu(c, name, mtu)` (68–65535; hardware caps
still apply), and `setPoe(c, name, mode)` (`auto-on` / `forced-on` /
`off` — off-then-auto-on is the remote power-cycle for a hung PoE
device; refuses ports without PoE).

```jennifer
def ls as mt.LinkStatus init mt.linkStatus($c, "ether1");
if ($ls.up and $ls.rate != "1Gbps") { io.printf("came up at %s!\n", $ls.rate); }
mt.setPoe($c, "ether5", "off");
mt.setPoe($c, "ether5", "auto-on");
```

**Interface lists** — named groups of interfaces (the v7 WAN/LAN
pattern): `addInterfaceList(c, name, comment)` → id,
`addToInterfaceList(c, listName, interfaceName)` → id (creates the list
if missing; idempotent), `interfaceLists(c)` → `list of InterfaceList`,
`interfaceListMembers(c, listName)` → `list of string`,
`removeFromInterfaceList` / `removeInterfaceList`. Firewall rules match a
whole group with the builder's `withInInterfaceList` /
`withOutInterfaceList` — add or move an interface and every rule follows.

```jennifer
mt.addToInterfaceList($c, "WAN", "ether1");
def r as mt.FirewallRule init mt.firewallRule(mt.CHAIN_INPUT, mt.ACTION_DROP);
$r = mt.withInInterfaceList($r, "WAN");  $r = mt.withComment($r, "drop from WAN");
mt.addFirewallRule($c, $r);
```

**LTE / cellular** — a mobile-broadband uplink (backup WAN, remote
sites): `lteInterfaces(c)` → `list of LteInterface` (empty on
non-cellular routers), `lteStatus(c, name)` → `LteStatus` (the live
measurement — `registered`, `operator`, `accessTechnology`, RSRP/RSRQ/
SINR — the first check on a flaky cellular link),
`setLteApn(c, name, apn)` (the usual "registered but no internet" fix),
`enableLte` / `disableLte(c, name)`.

**Bonding (link aggregation)** — several ethernet links acting as one
interface: `addLacpBond(c, name, "ether1,ether2")` → id (802.3ad, needs
a matching LACP group on the switch),
`addFailoverBond(c, name, slaves, primary)` → id (active-backup — pure
redundancy, works with any switch; the primary must be a member),
`addBond(c, name, slaves, mode)` for the other modes. Slave lists are
validated hard: at least two distinct existing interfaces, none already
serving another bond. `bonds(c)` → `list of Bond`, `bondByName`,
`setBondSlaves(c, name, slaves)`, `removeBond` / `enableBond` /
`disableBond(c, name)`; constants `BOND_LACP` / `BOND_ACTIVE_BACKUP`.
The bond behaves like any interface — bridge it, address it, VLAN it.

```jennifer
mt.addLacpBond($c, "bondtrunk", "ether1,ether2");
mt.addBridgePort($c, "brlan", "bondtrunk");
```

**Bridges** — `bridges(c)` → `list of Bridge`, `addBridge(c, name)` → id,
`removeBridge(c, name)`, `bridgePorts(c, bridgeName)` → `list of BridgePort`,
`addBridgePort(c, bridgeName, interfaceName)` → id,
`removeBridgePort(c, interfaceName)`.

**VLANs** — tagged virtual interfaces (`/interface/vlan`):
`addVlan(c, name, vlanId, interfaceName)` → id creates an 802.1Q-tagged
interface on a parent (VLAN id checked to 1–4094, parent checked to
exist); the result behaves like any interface — give it an address,
serve DHCP on it, bridge it. `vlans(c)` → `list of Vlan` (with `vlanId`
as an int), `vlanByName(c, name)`, `removeVlan` / `enableVlan` /
`disableVlan(c, name)`.

```jennifer
mt.addVlan($c, "vlanoffice", 20, "ether2");
mt.addIpAddress($c, "10.20.0.1/24", "vlanoffice");
mt.setupDhcp($c, "dhcpoffice", "vlanoffice", "10.20.0.0/24",
    "10.20.0.1", "10.20.0.10", "10.20.0.199", "10.20.0.1");
```

**Switch chip (hardware offload)** — on switch-capable boards a
VLAN-aware bridge forwards in the chip at wire speed automatically. This
topic lets you *see and verify* that: `switchChips(c)` →
`list of SwitchChip` (does this board have a chip; empty if not),
`switchHosts(c)` → `list of SwitchHost` (the chip's hardware MAC table —
populated = traffic really is hardware-switched). The `hw` intent flag
is on the bridge port: `BridgePort.hardwareOffload`, and
`setBridgePortHardwareOffload(c, interfaceName, on)` forces a port to
software forwarding (rarely wanted). "Confirm it's fast" = `hw=yes` +
low CPU + a populated `switchHosts`. Direct per-chip config (switch
rules, legacy VLAN table) stays with the generic verbs.

**Bridge VLAN filtering (the modern model)** — a VLAN-aware bridge tags
and filters per port instead of using `/interface/vlan` sub-interfaces
(bridges topic): `enableVlanFiltering(c, bridge)` /
`disableVlanFiltering(c, bridge)`,
`addBridgeVlan(c, bridge, vlanId, tagged, untagged)` → id (trunk vs.
access ports), `setPortPvid(c, bridge, port, pvid)`, `bridgeVlans(c)` →
`list of BridgeVlan`, `removeBridgeVlan(c, bridge, vlanId)`. **Danger:**
build the table + PVIDs FIRST, enable filtering LAST — enabling it on a
bridge carrying your management session drops you.

```jennifer
mt.addBridgeVlan($c, "brlan", 10, "ether1", "ether2,ether3");
mt.setPortPvid($c, "brlan", "ether2", 10);
mt.enableVlanFiltering($c, "brlan");   # last
```

**Firewall** — build a `FirewallRule` with
`firewallRule(chain, action)` and the value-semantic refiners
`withProtocol`, `withSrcAddress`, `withDstAddress`, `withSrcPort`,
`withDstPort`, `withInInterface`, `withOutInterface`, `withComment`,
`withDisabled`; then `addFirewallRule(c, rule)` → id. Read back with
`firewallRules(c)`; manage by the rule's comment with
`removeFirewallRuleByComment`, `enableFirewallRuleByComment`,
`disableFirewallRuleByComment`, or by id with `removeFirewallRule(c, id)`.
Shortcuts: `allowService(c, protocol, port, comment)` and
`blockAddress(c, address, comment)`. Interface-list matchers:
`withInInterfaceList` / `withOutInterfaceList` (see Interface lists).

**Firewall raw (pre-conntrack)** — the raw table runs *before*
connection tracking — the cheapest place to drop garbage (spoofs,
bogons, floods) or `notrack` traffic. Reuses the firewall builder
(chain `CHAIN_PREROUTING`/`CHAIN_OUTPUT`, action `accept`/`drop`/
`ACTION_NOTRACK`): `addRawRule(c, rule)` → id, the shortcut
`dropRawAddressList(c, listName, comment)` → id (bogon/blocklist
filtering), `rawRules(c)` → `list of RawRule`, `removeRawRule(c, id)` /
`removeRawRuleByComment(c, comment)`.

```jennifer
mt.dropRawAddressList($c, "bogons", "drop bogons early");
```

**NAT (masquerade & port forwarding)** —
`addMasquerade(c, outInterface, comment)` → id gives the LAN internet
access through the router's address (idempotent: an existing masquerade
rule for that interface is reused, never duplicated).
`forwardPort(c, protocol, publicPort, toAddress, toPort, comment)` → id
publishes an inside service;
`forwardPortOn(c, inInterface, ...)` pins the redirect to the WAN
interface so LAN-internal connections aren't hijacked (prefer it).
Protocol is checked to tcp/udp, ports to 1–65535, the target to a real
IP. Read back with `natRules(c)` → `list of NatRule`; manage by comment
with `removeNatRuleByComment` / `enableNatRuleByComment` /
`disableNatRuleByComment` (temporarily close a forward without losing
it), or by id with `removeNatRule(c, id)`.

```jennifer
mt.addMasquerade($c, "ether1", "lan to internet");
mt.forwardPortOn($c, "ether1", "tcp", 8080, "192.168.88.10", 80, "web server");
```

**UPnP** — let LAN devices open their own port forwards (convenient,
but any LAN device can punch a hole — weigh it, never on a guest net):
`enableUpnp(c)` / `disableUpnp(c)`, `upnpStatus(c)` → `UpnpSettings`,
`setUpnpInterface(c, interfaceName, "internal"|"external")` (mark LAN vs
WAN side), `upnpInterfaces(c)`, `removeUpnpInterface(c, interfaceName)`.

**Traffic flow (NetFlow/IPFIX)** — export per-flow records to a
collector (ntopng, Elastiflow) for bandwidth/top-talker analysis:
`enableTrafficFlow(c)` / `disableTrafficFlow(c)`,
`addFlowTarget(c, address, port, version)` → id (`"5"`/`"9"`/`"ipfix"`;
idempotent), `flowTargets(c)` → `list of FlowTarget`,
`removeFlowTarget(c, address)`, `trafficFlowStatus(c)` →
`TrafficFlowSettings`.

**Address lists** — named sets of addresses the firewall references as
a whole: keep *one* rule and maintain only the list.
`addToAddressList(c, listName, address, comment)` → id (IP, CIDR, or
DNS name; idempotent), `addToAddressListTimed(c, listName, address,
timeout, comment)` → id (self-expiring entries, e.g. `"1d"`),
`removeFromAddressList(c, listName, address)`,
`clearAddressList(c, listName)` (static entries only),
`addressLists(c)` → `list of string`,
`addressListEntries(c, listName)` → `list of AddressListEntry`, and
`dropAddressList(c, listName, chain, comment)` → id for the one rule
that drops every member. The firewall builder gained the matching
refiners `withSrcAddressList` / `withDstAddressList`.

```jennifer
mt.dropAddressList($c, "blocklist", mt.CHAIN_INPUT, "drop blocklisted");
mt.addToAddressList($c, "blocklist", "203.0.113.7", "ssh scanner");
mt.addToAddressListTimed($c, "blocklist", "192.0.2.66", "1d", "brute force");
```

**Mangle (packet marking)** — marks connect the firewall's matching to
queues and routing. `setupPacketMark(c, markName, matcher)` → id builds
RouterOS's canonical two-step (mark new connections, then their
packets) from a matcher made with the firewall builder — its chain is
honored (`CHAIN_PREROUTING` is right for queue marks), its action
replaced; queues then match the packet mark (`packet-marks` via generic
`set`). `markRoutingFor(c, markName, srcAddress)` → id sends a
subnet/host to another routing table (v7: create the table first via
generic verbs — see the docblock), and `clampTcpMss(c, interfaceName)`
fixes "ping works, pages hang" over PPPoE/tunnels (both directions,
idempotent). Read back with `mangleRules(c)` → `list of MangleRule`;
undo with `removePacketMark(c, markName)`,
`removeRoutingMark(c, markName, srcAddress)`,
`removeTcpMssClamp(c, interfaceName)`. All setup helpers are idempotent
by their comment convention.

```jennifer
def m as mt.FirewallRule init mt.firewallRule(mt.CHAIN_PREROUTING, mt.ACTION_ACCEPT);
$m = mt.withProtocol($m, "udp");
$m = mt.withDstPort($m, "5060-5200");
mt.setupPacketMark($c, "voip", $m);
mt.clampTcpMss($c, "pppoewan");
```

**IP addresses** — `ipAddresses(c)` → `list of IpAddress`,
`addIpAddress(c, address, interfaceName)` → id (address must carry its
prefix, e.g. `"192.168.88.1/24"`), `removeIpAddress(c, address)`.

**ARP table** — who is on the network: `arpTable(c)` →
`list of ArpEntry` (doubles as a "who is on my LAN" list),
`arpTableOn(c, interfaceName)`, `macForAddress(c, address)` → MAC or
`""` (a miss is normal, not an error), `addressesForMac(c, mac)` →
`list of string` (the reverse lookup, case-insensitive);
`addStaticArp(c, address, mac, interfaceName)` → id pins a binding
(pair with `arp=reply-only` on the interface for locked-down LANs;
refuses to overwrite an existing static entry),
`removeArpEntry(c, address)` (also clears a stale dynamic binding after
a hardware swap), and `flushArp(c, interfaceName)` → count (drop all
dynamic entries; static ones stay).

```jennifer
io.printf("printer is at %s\n", mt.macForAddress($c, "192.168.88.50"));
mt.addStaticArp($c, "192.168.88.50", "AA:BB:CC:DD:EE:FF", "brlan");
```

**Neighbor discovery** — "what's plugged into this segment" via
LLDP/CDP/MNDP: `neighbors(c)` → `list of Neighbor` (identity, platform,
board, version, address per directly-connected device),
`neighborsOn(c, interfaceName)`.

**DHCP server** — the one-shot
`setupDhcp(c, name, interfaceName, network, gateway, rangeFrom, rangeTo, dns)`
creates the three objects RouterOS needs (address pool, server, network
entry) with everything cross-checked — gateway and range must lie inside
the network, the interface must exist; `teardownDhcp(c, name, network)`
undoes all of it. Plus `dhcpServers(c)` → `list of DhcpServer`,
`dhcpLeases(c)` → `list of DhcpLease`,
`addStaticLease(c, address, mac, comment)` → id (reserve a fixed IP for
a device), `removeLeaseByMac(c, mac)`.

```jennifer
mt.addIpAddress($c, "192.168.77.1/24", "brlan");
mt.setupDhcp($c, "dhcplan", "brlan", "192.168.77.0/24",
    "192.168.77.1", "192.168.77.10", "192.168.77.199", "192.168.77.1");
mt.addStaticLease($c, "192.168.77.50", "AA:BB:CC:DD:EE:FF", "printer");
```

**DHCP client (WAN)** — `setupWan(c, interfaceName)` → id configures
the internet-facing port with the usual defaults (adopt the ISP's
default route and DNS); idempotent — an existing client on that
interface is reused. `setupWanWith(c, interfaceName, usePeerDns,
addDefaultRoute)` opts out of either, e.g. for a backup uplink managed
with `addRouteWithDistance`. `wanStatus(c, interfaceName)` →
`DhcpClient` tells you whether the lease is `bound` and which address,
gateway, and DNS the ISP handed out; `renewWan(c, interfaceName)` asks
for a fresh lease; `dhcpClients(c)` → `list of DhcpClient`, and
`removeDhcpClient` / `enableDhcpClient` / `disableDhcpClient(c,
interfaceName)` manage by interface. Together with NAT this is the
whole internet recipe:

```jennifer
mt.setupWan($c, "ether1");
mt.addMasquerade($c, "ether1", "lan to internet");
def wan as mt.DhcpClient init mt.wanStatus($c, "ether1");
if ($wan.bound) { io.printf("online as %s via %s\n", $wan.address, $wan.gateway); }
```

**DHCP relay** — forward a network's DHCP requests to a central server
instead of running one locally:
`addDhcpRelay(c, name, interfaceName, serverAddress)` → id (idempotent),
`dhcpRelays(c)` → `list of DhcpRelay`, `removeDhcpRelay(c, name)`.

**PPPoE client (WAN dial-in)** — the DSL/fiber counterpart to the DHCP
WAN: `setupPppoe(c, name, interfaceName, user, password)` → id dials in
with the ISP's credentials on a physical port, installing the default
route and adopting the ISP's DNS (idempotent by name). The resulting
PPPoE interface is what you masquerade. `pppoeStatus(c, name)` →
`PppoeClient` (check `running`), `setPppoeCredentials(c, name, user,
password)`, `pppoeClients(c)` → `list of PppoeClient`, and
`removePppoeClient` / `enablePppoeClient` / `disablePppoeClient(c,
name)`. The password is write-only — it never appears in a struct.
(RouterOS's `/ppp` menu itself holds the *server-side* secrets and
profiles; drive those with the generic verbs.)

```jennifer
mt.setupPppoe($c, "pppoewan", "ether1", "user@provider.example", "secret");
mt.addMasquerade($c, "pppoewan", "lan to internet");
```

**PPPoE server** — the other side: the router accepts PPPoE dial-ins
(a concentrator for downstream routers/offices).
`addPppoeServer(c, serviceName, interfaceName)` → id (idempotent),
`pppoeServers(c)` → `list of PppoeServer`,
`removePppoeServer(c, serviceName)` — clients authenticate against the
shared PPP user DB, so add logins with `addVpnUser(…, "pppoe", …)`.

**Remote-access VPN** — the road-warrior servers share one PPP user
database (`addVpnUser(c, name, password, service, comment)`,
`vpnUsers(c)`, `removeVpnUser`, `pppActive(c)` for who is connected,
`kickPppUser(c, name)`). Turn a server on, then add users:
`enableLtwotpServer(c, ipsecSecret)` (L2TP/IPsec — native on every OS;
opens IKE/NAT-T/ESP + udp 1701), `enableSstpServer(c, certificate,
port)` (TLS on 443, crosses firewalls), `enableOvpnServer(c,
certificate, port)` (OpenVPN); each with a `disable…Server(c)` that also
removes its firewall openings, and TLS servers needing a certificate
(certificates topic). Dial OUT with `addLtwotpClient` / `addSstpClient` /
`addOvpnClient(c, name, serverAddress, user, password)` (+ list/remove),
and `setupIkevTwoServer(c, name, certificate, poolRange, dns)` for native
IKEv2 road-warriors (ipsec topic).

```jennifer
mt.enableLtwotpServer($c, "a long random ipsec secret");
mt.addVpnUser($c, "alice", "her password", "any", "field laptop");
# clients dial the router's public address/name with that PSK + login
```

**Hotspot (guest portal)** — the captive portal, composed on top of
`setupDhcp`: `setupHotspot(c, name, interfaceName, network, gateway,
rangeFrom, rangeTo)` → id builds the DHCP stack, profile, and portal on
a **dedicated** guest interface (never the management LAN — the portal
intercepts everything); `teardownHotspot(c, name, network)` undoes it.
Logins: `addHotspotUser(c, name, password, comment)` → id and the
front-desk `addHotspotVoucher(c, name, password, "1d", comment)` → id
(time-limited), `hotspotUsers(c)`, `removeHotspotUser(c, name)`.
Operations: `hotspotActive(c)` → `list of HotspotSession` (usage
counters), `kickHotspotUser(c, user)`,
`bypassHotspotMac(c, mac, comment)` → id (printers/TVs skip the login;
idempotent), `removeHotspotBypass(c, mac)`,
`allowBeforeLogin(c, dstHost, comment)` → id (walled garden) and
`removeWalledGardenEntry(c, dstHost)`.

```jennifer
mt.addIpAddress($c, "10.5.50.1/24", "brguest");
mt.setupHotspot($c, "guests", "brguest", "10.5.50.0/24",
    "10.5.50.1", "10.5.50.10", "10.5.50.254");
mt.addHotspotVoucher($c, "visitor", "day pass 123", "1d", "front desk");
```

**DNS** — `dnsSettings(c)` → `DnsSettings`,
`setDnsServers(c, "1.1.1.1,9.9.9.9")`,
`allowRemoteDnsRequests(c, allow)` (needed when DHCP clients use the
router as resolver — mind the open-resolver warning in the docblock),
`dnsStaticEntries(c)` → `list of DnsEntry`,
`addDnsEntry(c, "nas.lan", "192.168.77.50")` → id,
`removeDnsEntry(c, name)`. The cache: `dnsCache(c)` →
`list of DnsCacheEntry` (record type, data, ttl, `isStatic`),
`dnsCacheFor(c, name)` (case-insensitive; "what would the router answer
right now"), `resolvedAddresses(c, name)` → `list of string` (A/AAAA
only), and `flushDnsCache(c)` — the "it still resolves the old address"
fix; static entries survive. Ad/malware blocking (7.15+):
`dnsAdlists(c)` → `list of DnsAdlist`, `addAdlist(c, url)` (idempotent),
`removeAdlist(c, url)`.

**Static routes** — RouterOS keeps these under `/ip/route` (the
`/routing` menu is for OSPF/BGP): `routes(c)` → `list of Route`
(static, connected, and dynamic; filter on `.dynamic`),
`addRoute(c, dstAddress, gateway, comment)` → id,
`addDefaultRoute(c, gateway, comment)` → id ("the internet is that
way"), `addRouteWithDistance(c, dstAddress, gateway, distance, comment)`
→ id (higher distance = backup route),
`removeRoute` / `enableRoute` / `disableRoute(c, dstAddress)` (match the
first *static* route to that destination; dynamic routes are never
touched). The gateway may be an IP address or an interface name — if it
is not an IP, routeros verifies the interface exists before adding.

```jennifer
mt.addDefaultRoute($c, "203.0.113.1", "isp uplink");
mt.addRoute($c, "10.20.0.0/16", "192.168.88.254", "to branch office");
mt.addRouteWithDistance($c, "10.20.0.0/16", "192.168.89.254", 10, "branch backup");
```

Policy routing rules (`/routing/rule`, v7; v6 kept them under
`/ip/route/rule` — generic verbs): the mark-free way to say "this
subnet uses another uplink". `useRoutingTable(c, srcAddress, table,
comment)` → id (action `lookup`, falls back to main; the table is
created if missing — give it a default route),
`useRoutingTableOnly(...)` (strict, no fallback), `routingRules(c)` →
`list of RoutingRule`, `removeRoutingRule(c, srcAddress, table)`. The
mangle topic's `markRoutingFor` covers matches that need firewall
power; rules are simpler and cheaper when a source match suffices.

```jennifer
mt.useRoutingTable($c, "10.30.0.0/24", "backupisp", "guests via backup");
mt.add($c, mt.ROUTE_PATH, {"dst-address": "0.0.0.0/0",
    "gateway": "198.51.100.1", "routing-table": "backupisp"});
```

**Simple queues (bandwidth limiting)** —
`limitBandwidth(c, name, target, upload, download)` → id caps a device,
network, interface, or comma-separated mix (upload = traffic *from* the
target, download = traffic *to* it; rates like `"10M"`, `"512k"`,
`"1G"`, plain bits/s, or `"0"` for unlimited — validated and normalized
locally). `setBandwidthLimit(c, name, upload, download)` changes an
existing cap, `simpleQueues(c)` → `list of SimpleQueue` (with the
`max-limit` pair already split into `maxUpload` / `maxDownload`), and
`removeSimpleQueue` / `enableSimpleQueue` / `disableSimpleQueue(c, name)`
manage it by name.

```jennifer
mt.limitBandwidth($c, "guest-wifi", "192.168.90.0/24", "5M", "20M");
mt.setBandwidthLimit($c, "guest-wifi", "10M", "50M");
```

Hierarchical QoS (`/queue/tree`, `QUEUE_TREE_PATH`) — classes share a
line by *kind* of traffic, fed by mangle packet marks:
`addQueueTreeRoot(c, name, parent, maxLimit)` → id (parent = an
interface's egress or `"global"`; set the budget slightly below the
real line rate), `addQueueTreeChild(c, name, parentName, packetMark,
limitAt, maxLimit, priority)` → id (guaranteed share + ceiling +
priority 1–8; a mark no mangle rule creates is refused),
`treeQueues(c)` → `list of TreeQueue`, `removeTreeQueue(c, name)`
(removes the whole subtree, children first), `enableTreeQueue` /
`disableTreeQueue(c, name)`.

```jennifer
mt.addQueueTreeRoot($c, "qosup", "pppoewan", "38M");
mt.addQueueTreeChild($c, "qosupvoip", "qosup", "voip", "5M", "38M", 1);
mt.addQueueTreeChild($c, "qosupbulk", "qosup", "bulk", "10M", "38M", 8);
```

**Wireless (WiFi)** — targets the classic `/interface/wireless` menu
(wifiwave2/ax routers use `/interface/wifi`; drive that with the generic
verbs). The one-call
`setupWifiAccessPoint(c, interfaceName, ssid, password)` sets the SSID,
switches the radio to access-point mode, stores the WPA2 passphrase in
a dedicated security profile (`routeros-<interface>` — the shared
`default` profile is never touched), wires it up, and enables the
interface; calling it again changes SSID/password. Also
`setWifiSsid(c, interfaceName, ssid)`,
`setWifiPassword(c, interfaceName, password)` (moves the interface off
the `default` profile automatically),
`addVirtualAp(c, masterInterface, name, ssid, password)` → id (guest
WiFi: second SSID with its own password on the same radio),
`removeVirtualAp(c, name)` (refuses physical radios),
`enableWifi` / `disableWifi(c, interfaceName)`,
`wirelessInterfaces(c)` → `list of WirelessInterface`, and
`wifiClients(c)` → `list of WifiClient` (who is connected, with signal
and rates). SSIDs are checked to 1–32 characters, passphrases to WPA2's
8–63.

```jennifer
mt.setupWifiAccessPoint($c, "wlan1", "My Home WiFi", "correct horse battery");
mt.addVirtualAp($c, "wlan1", "wlanguest", "Guest WiFi", "changeme123");
```

**WireGuard VPN (RouterOS v7)** — the one-call
`setupWireguardServer(c, name, listenPort, address)` creates the
interface (the router generates the keypair — the private key never
leaves it), assigns the VPN address, and opens the UDP port in the
firewall; all three pieces idempotent. `wireguardPublicKey(c, name)`
reads the key to hand to the other side.
`addWireguardPeer(c, interfaceName, publicKey, allowedAddress, comment)`
lets a device in (allowed-address checked to carry a prefix — a single
device is `/32`); `connectWireguard(c, interfaceName, publicKey,
endpointHost, endpointPort, allowedAddress, comment)` dials out to a
remote server with NAT-friendly keepalive. `wireguardInterfaces(c)` /
`wireguardPeers(c)` report state (`lastHandshake` is the liveness
signal), `removeWireguardPeerByComment(c, comment)` and
`removeWireguard(c, name)` (also cleans up the address and firewall
rule) tear down, plus `enableWireguard` / `disableWireguard(c, name)`.
Keys are validated locally (44 base64 chars ending `=`).

```jennifer
mt.setupWireguardServer($c, "wgvpn", 13231, "10.100.0.1/24");
io.printf("server key: %s\n", mt.wireguardPublicKey($c, "wgvpn"));
mt.addWireguardPeer($c, "wgvpn", $laptopKey, "10.100.0.2/32", "laptop");
```

**EoIP tunnels** — MikroTik's layer-2 wire between two routers: bridge
the tunnel on both ends and two sites share one LAN across any IP path.
`addEoipTunnel(c, name, remoteAddress, tunnelId)` → id (both ends must
mirror each other: swapped remote addresses, the **same** tunnel id
0–65535; a clashing remote+id pair is refused with the owning tunnel
named). EoIP itself is **unencrypted** — use
`addSecureEoipTunnel(c, name, remoteAddress, tunnelId, ipsecSecret)`
(RouterOS's coupled IPsec, same secret both ends, write-only) or run it
over WireGuard. `eoipTunnels(c)` → `list of EoipTunnel`,
`eoipTunnelByName`, `removeEoipTunnel` / `enableEoipTunnel` /
`disableEoipTunnel(c, name)`.

```jennifer
mt.addEoipTunnel($c, "eoipbranch", "10.100.0.2", 7);   # over WireGuard
mt.addBridgePort($c, "brlan", "eoipbranch");           # LAN now spans both sites
```

**GRE tunnels** — the routed sibling of EoIP: a standard (RFC 2784)
point-to-point layer-3 link, so the far end may be any vendor.
`addGreTunnel(c, name, remoteAddress)` → id (mirror it on the far end;
a second tunnel to the same remote is refused with the owner named),
then address both ends in a small shared network and route through it:

```jennifer
mt.addGreTunnel($c, "grebranch", "203.0.113.99");
mt.addIpAddress($c, "10.99.0.1/30", "grebranch");
mt.addRoute($c, "192.168.20.0/24", "10.99.0.2", "branch LAN via GRE");
```

GRE is **unencrypted** —
`addSecureGreTunnel(c, name, remoteAddress, ipsecSecret)` adds
RouterOS's coupled IPsec (same secret both ends, write-only). Plus
`greTunnels(c)` → `list of GreTunnel`, `greTunnelByName`,
`removeGreTunnel` / `enableGreTunnel` / `disableGreTunnel(c, name)`.

**IPsec (site-to-site)** — standards-based tunnels for multi-vendor
far ends (between two MikroTiks, WireGuard is simpler).
`setupIpsecTunnel(c, name, peerAddress, psk, localSubnet,
remoteSubnet)` → id builds everything in one call: IKEv2 peer +
pre-shared-key identity, the encrypting policy, the **NAT bypass**
(accept placed *before* masquerade — the classic silent failure), and
firewall accepts for IKE/NAT-T/ESP. Mirror the call on the far end
(same PSK, subnets swapped); `teardownIpsecTunnel(c, name)` removes all
of it. Status: `ipsecActive(c)` → `list of IpsecActivePeer` (computed
`established`), `ipsecPolicies(c)` (per-policy `active` flag),
`ipsecPeers(c)`. For native road-warrior clients (iOS/macOS/Windows
IKEv2), `setupIkevTwoServer(c, name, certificate, poolRange, dns)` builds
the mode-config + passive peer + EAP identity + firewall — the most
involved VPN to finish end-to-end (see the guide).

```jennifer
mt.setupIpsecTunnel($c, "tobranch", "203.0.113.99",
    "a long random shared secret", "192.168.10.0/24", "192.168.20.0/24");
def live as list of mt.IpsecActivePeer init mt.ipsecActive($c);
for (def a in $live) { io.printf("%s: %s\n", $a.remoteAddress, $a.state); }
```

**VRRP (gateway redundancy)** — two routers guard one virtual gateway
address; clients notice nothing when one dies. The one-call
`setupVrrp(c, name, interfaceName, vrid, priority, virtualAddress)` →
id creates the instance and puts the shared address on it — run it on
both routers with the same `vrid` (1–255) and address but different
priorities (1–254, highest wins; a vrid clash on the interface is
refused with the owner named). `vrrpInterfaces(c)` /
`vrrpByName(c, name)` report state with a computed `master` flag,
`setVrrpPriority(c, name, priority)` is the failover dial (lower it
before maintenance), `removeVrrp(c, name)` also removes the virtual
address, plus `enableVrrp` / `disableVrrp(c, name)`.

```jennifer
# preferred router:
mt.setupVrrp($c, "vrrplan", "brlan", 10, 200, "192.168.88.254/32");
# standby (other router): same vrid + address, priority 100
def v as mt.VrrpInterface init mt.vrrpByName($c, "vrrplan");
if ($v.master) { io.printf("I am the gateway\n"); }
```

**Modern WiFi (wifiwave2/ax, RouterOS v7)** — the `/interface/wifi`
counterpart to the classic wireless topic; each returns empty lists on
the other kind of hardware. `setupWifi(c, "wifi1", ssid, password)`
(WPA2+WPA3, idempotent), `setWifiPassphrase(c, iface, password)`,
`addVirtualWifi(c, master, name, ssid, password)` → id (guest WiFi),
`removeVirtualWifi(c, name)` (refuses physical radios),
`wifiInterfaces(c)` → `list of WifiInterface`, `wifiRegistrations(c)` →
`list of WifiRegistration` (who is connected). Enable/disable via the
generic `enableInterface` / `disableInterface`.

**Diagnostics** — run from the router's point of view:
`ping(c, host)` → `PingResult` (4 probes; `host` may be an IP or DNS
name), `pingWith(c, host, count)` (1–100 probes — a count is always
sent, because an unbounded RouterOS ping never returns), and the yes/no
shortcut `isReachable(c, host)` → bool. `PingResult` carries
sent/received/loss as ints, the min/avg/max round trips, and a computed
`reachable` flag. `bandwidthTest(c, host, seconds, direction)` →
`BandwidthResult` measures throughput against a btest server (another
MikroTik with `/tool/bandwidth-server` enabled); direction is
`"receive"`, `"transmit"`, or `"both"`, duration 1–300 s;
`bandwidthTestWith(...)` adds btest credentials. Mind the docblock
warning: the test saturates the link while it runs.

Plus `traceroute(c, host)` → `list of TracerouteHop` (the path, and
where it breaks), `fetchUrl(c, url)` → `FetchResult` (the router fetches
a URL — call a webhook, check its own public IP; body in `.data`),
`downloadFile(c, url, fileName)` (save to storage), and e-mail alerting:
`configureEmail(c, server, port, from, user, password)` once, then
`sendEmail(c, recipient, subject, body)` (pairs with scheduler/netwatch
for "WAN down" mails).

```jennifer
if (not mt.isReachable($c, "1.1.1.1")) {
    io.printf("uplink looks down\n");
}
def hops as list of mt.TracerouteHop init mt.traceroute($c, "1.1.1.1");
def ip as mt.FetchResult init mt.fetchUrl($c, "https://ifconfig.co/ip");
if ($ip.ok) { io.printf("public IP: %s\n", $ip.data); }
```

**Router users** — `users(c)` → `list of User`, `userGroups(c)`,
`activeUsers(c)` (who is logged in, from where, via what);
`addUser(c, name, password, group)` → id with the group constants
`GROUP_FULL` / `GROUP_WRITE` / `GROUP_READ` (group must exist, name
must not, password must be non-empty — and is write-only ever after);
`setUserPassword`, `setUserGroup`, `restrictUser(c, name, addresses)`
(limit login sources to IPs/CIDRs, `""` lifts it), `removeUser`,
`enableUser` / `disableUser`. The `Client` knows which account it is
logged in as, so `removeUser`, `disableUser`, and `setUserGroup`
**refuse to target your own account** — the classic mid-session
lockout is caught locally.

```jennifer
mt.addUser($c, "monitoring", "a long random password", mt.GROUP_READ);
mt.restrictUser($c, "monitoring", "10.0.9.0/24");
```

**Management services** — the fixed list of ways into the router
(`api`, `api-ssl`, `ftp`, `ssh`, `telnet`, `winbox`, `www`, `www-ssl`):
`services(c)` → `list of Service` (port as int, source restriction,
`invalid` flag for misconfigured ssl), `serviceByName(c, name)`,
`enableService` / `disableService(c, name)` (mind the docblock: don't
disable the service your own session came through),
`setServicePort(c, name, port)` (a port used by another service is
refused with the owner named — moving ssh/winbox cuts scanner noise,
combine with restriction), `restrictService(c, name, addresses)`
(IPs/CIDRs, the most effective hardening step; `""` lifts it), and
`disableInsecureServices(c)` → count (switches off the cleartext
relics telnet and ftp — never your API session).

```jennifer
mt.disableInsecureServices($c);
mt.restrictService($c, "winbox", "10.0.9.0/24");
mt.restrictService($c, "ssh", "10.0.9.0/24");
mt.setServicePort($c, "ssh", 2200);
```

**Certificates** — `certificates(c)` → `list of Certificate` (CN,
issuer, `hasPrivateKey`, expiry), `certificateByName`,
`expiringCertificates(c, withinDays)` (the renewal audit; RouterOS
durations like `"51w6d"` are parsed to days),
`generateSelfSigned(c, name, commonName, days)` → id (LAN-only TLS,
signed on the router), `enableLetsEncrypt(c, dnsName)` (RouterOS v7
built-in ACME — needs port 80 reachable under the name),
`importCertificatePem(c, name, certPem, keyPem)` (the drop-in for
externally obtained certs, e.g. the Jennifer `acme` module — temp files
are cleaned up), `assignServiceCertificate(c, "api-ssl", certName)`
(turns an `invalid` ssl service into a running one), and
`removeCertificate(c, name)`.

```jennifer
mt.generateSelfSigned($c, "router-lan", "router.lan", 1095);
mt.assignServiceCertificate($c, "api-ssl", "router-lan");
```

**Clock & NTP** — MikroTiks have no battery clock: `useNtp(c,
"pool.ntp.org")` + `setTimezone(c, "Europe/Berlin")` is part of every
sane base config (certificates, schedules, and logs depend on it).
`clock(c)` → `Clock`, `ntpStatus(c)` → `NtpStatus` (computed `synced`
flag), `disableNtp(c)`.

**Files & backups** — `files(c)` → `list of RouterFile`,
`saveBackup(c, name)` (verified to appear; contains secrets — prefer
`saveBackupWith(c, name, password)` for anything leaving the router),
`readFileText` / `writeFileText(c, name, contents)` (small text files,
v7 — what the certificate import rides on), `removeFile(c, name)`.
Restoring a backup is deliberately not wrapped.

**Disks** — USB/NVMe/SATA storage (where containers, backups, and
downloads live): `disks(c)` → `list of Disk` (`sizeBytes`/`freeBytes`
as ints; empty on routers with no storage), `diskByName(c, name)`,
`ejectDisk(c, name)`, and **`formatDisk(c, name, filesystem, label)`**
(ext4/fat32/exfat/btrfs/vfat) — **destructive and irreversible, erases
the whole disk**; double-check the name.

**Cloud DDNS** — a stable name for a dynamic WAN:
`enableCloudDns(c)` registers `<serial>.sn.mynetname.net` and forces an
update, `routerDnsName(c)` → the name to hand to road warriors
(`connectWireguard`, `enableLetsEncrypt`), `cloudStatus(c)` →
`CloudStatus`, `disableCloudDns(c)`.

**Connection tracking** — the live connection table:
`conntrackSettings(c)` → `ConntrackSettings` (how full),
`connections(c)` → `list of Connection` (large — prefer filtering),
`connectionsFor(c, address)` (what a host is talking to), and
`dropConnectionsFor(c, address)` → count (cut a host off / reset stuck
connections).

**System health** — `healthSensors(c)` → `list of HealthSensor`
(temperature, voltage, fan speeds — model-dependent, empty is normal),
`healthValue(c, "cpu-temperature")` → the reading or `""`.

**RADIUS** — central auth for logins/VPN/hotspot:
`addRadiusServer(c, address, secret, services, comment)` → id (services
like `"login,ppp,hotspot"`; secret write-only; idempotent),
`radiusServers(c)`, `removeRadiusServer(c, address)`.

**Containers (v7)** — `containers(c)` → `list of Container`,
`addContainer(c, name, remoteImage, interfaceName, rootDir)` → id (a
veth and container support are prerequisites — see the guide),
`startContainer` / `stopContainer` / `removeContainer(c, name)`.

**CAPsMAN** — central management of many APs, both generations:
`capsmanStatus(c)` → `CapsmanStatus` (`version` 1 legacy / 2 wifiwave2 /
0 none), `enableCapsman(c)` / `disableCapsman(c)`, `managedAps(c)` →
`list of ManagedAp`. The SSID/security configuration + provisioning
rules stay with the generic verbs (their shape differs by generation).

**SNMP** — `enableSnmp(c, community, addresses)` → id (read-only
community, source-restricted, agent on — idempotent; v2c is cleartext,
treat the community like a password and consider disabling the default
`public`), `setSnmpInfo(c, contact, location)`, `snmpSettings(c)`,
`snmpCommunities(c)`, `disableSnmp(c)`.

**Log** — the entries live at `/log`; `/system/logging` decides what is
logged where. Reading: `logEntries(c)` → `list of LogEntry` (the
in-memory buffer, oldest first), `recentLogEntries(c, count)` (the
tail), `logEntriesWithTopic(c, "firewall")` (exact-word topic match),
and the health shortcut `logErrors(c)` (topics `error` / `critical` —
empty is good news). Routing: `loggingRules(c)` → `list of
LoggingRule`, `addLoggingRule(c, topics, action)` → id (topics
validated and normalized, `"info,!dns"` style negation supported;
action checked against the router's actions; idempotent),
`removeLoggingRule(c, topics, action)`, and the one-call
`setupRemoteLogging(c, address, port, topics)` that points the built-in
`remote` action at a syslog server and routes the topics there.

```jennifer
def problems as list of mt.LogEntry init mt.logErrors($c);
for (def e in $problems) { io.printf("%s %s: %s\n", $e.time, $e.topics, $e.message); }

mt.addLoggingRule($c, "firewall", "disk");
mt.setupRemoteLogging($c, "192.168.88.40", 514, "info,warning,error,critical");
```

**System** — `systemInfo(c)` → `SystemInfo` (version, board, uptime,
load, memory), `identity(c)` / `setIdentity(c, name)` (router name),
`packages(c)` → `list of Package`. Updating:
`checkForUpdates(c)` → `UpdateStatus` (read-only; check
`.updateAvailable`), `downloadUpdates(c)` (fetch now, install on next
reboot), `installUpdates(c)` (download, install, **reboots the
router**). Firmware: `routerboard(c)` → `Routerboard` (check
`.upgradeAvailable`), `upgradeRouterboard(c)` (stages the flash for the
next reboot). Power: `reboot(c)`, `shutdown(c)`. The full update runs:

```jennifer
if (mt.checkForUpdates($c).updateAvailable) {
    mt.installUpdates($c);          # router reboots itself
    # ... wait, then reconnect ...
    mt.upgradeRouterboard($c);      # flash matching firmware
    mt.reboot($c);                  # firmware takes effect
}
```

`installUpdates`, `reboot`, and `shutdown` swallow the transport error
caused by the connection dropping (that is what success looks like) but
still re-throw a real router refusal, e.g. a missing reboot policy.

**Netwatch (host monitoring)** — the router probes hosts continuously
and remembers state: `watchHost(c, host, comment)` → id (idempotent),
`watchHostWith(c, host, interval, comment)` for an explicit probe
interval, and `watchHostScripted(c, host, downScript, upScript,
comment)` to react to state flips with RouterOS scripts (the alerting
hook — at least one script required). `hostStatus(c, host)` →
`NetwatchHost` (computed `up`, and `since` — the useful half of an
outage report), `downHosts(c)` (the morning sweep; empty is good news),
`netwatchHosts(c)`, `unwatchHost(c, host)`, and
`disableWatch` / `enableWatch(c, host)` — all keyed by host.

```jennifer
mt.watchHostScripted($c, "192.168.88.50",
    ":log warning \"printer went down\"", ":log info \"printer is back\"", "printer");
def down as list of mt.NetwatchHost init mt.downHosts($c);
for (def d in $down) { io.printf("%s down since %s\n", $d.host, $d.since); }
```

**Scheduler (scripts on a timer)** —
`scheduleScript(c, name, interval, source)` → id runs RouterOS script
source (or the name of a `/system/script`) every interval (`"30s"`,
`"10m"`, `"1d"`, combined `"1d12h"`, or `"HH:MM:SS"` — validated
locally); `scheduleDaily(c, name, "03:00:00", source)` → id for a fixed
daily time; `scheduleAtStartup(c, name, source)` → id for run-at-boot.
`scheduledTasks(c)` → `list of ScheduledTask` (with `nextRun` and an
int `runCount`), and `removeScheduledTask` / `enableScheduledTask` /
`disableScheduledTask(c, name)` manage by name. The script runs with
the rights of the user the client is logged in as.

```jennifer
mt.scheduleDaily($c, "nightly-backup", "03:00:00",
    "/system backup save name=nightly");
mt.scheduleScript($c, "watchdog", "10m",
    "/ping 1.1.1.1 count=3");
```

**Scripts (the repository)** — store RouterOS scripts once and reuse
them (the scheduler/netwatch run them by name): `scripts(c)` →
`list of Script`, `scriptByName(c, name)`,
`addScript(c, name, source, comment)` → id (fails if the name is taken),
`updateScript(c, name, source)`, `runScript(c, name)` → the return
value, `removeScript(c, name)`.

```jennifer
mt.addScript($c, "nightly", "/system backup save name=nightly", "backup");
mt.scheduleDaily($c, "run-nightly", "03:00:00", "nightly");   # run it by name
```

**Constants** — chains `CHAIN_INPUT` / `CHAIN_FORWARD` / `CHAIN_OUTPUT`,
actions `ACTION_ACCEPT` / `ACTION_DROP` / `ACTION_REJECT`, NAT chains
`CHAIN_SRCNAT` / `CHAIN_DSTNAT` with actions `ACTION_MASQUERADE` /
`ACTION_DST_NAT`, and the paths
`INTERFACE_PATH` / `INTERFACE_LIST_PATH` / `INTERFACE_LIST_MEMBER_PATH` /
`LTE_PATH` / `LTE_APN_PATH` /
`ETHERNET_PATH` / `BONDING_PATH` / `BRIDGE_PATH` /
`BRIDGE_PORT_PATH` / `BRIDGE_VLAN_PATH` / `ETHERNET_SWITCH_PATH` /
`ETHERNET_SWITCH_HOST_PATH` / `VLAN_PATH` /
`FIREWALL_PATH` / `RAW_PATH` / `NAT_PATH` / `ADDRESS_LIST_PATH` /
`MANGLE_PATH` /
`CONNTRACK_SETTINGS_PATH` / `CONNECTION_PATH` /
`ROUTE_PATH` / `ROUTING_RULE_PATH` / `ROUTING_TABLE_PATH` /
`UPNP_PATH` / `UPNP_INTERFACES_PATH` / `TRAFFIC_FLOW_PATH` / `TRAFFIC_FLOW_TARGET_PATH` /
`ARP_PATH` / `NEIGHBOR_PATH` / `QUEUE_SIMPLE_PATH` / `QUEUE_TREE_PATH` /
`WIRELESS_PATH` /
`WIRELESS_SECURITY_PATH` / `WIRELESS_REGISTRATION_PATH` /
`WIREGUARD_PATH` / `WIREGUARD_PEER_PATH` / `EOIP_PATH` / `GRE_PATH` /
`IPSEC_PEER_PATH` / `IPSEC_IDENTITY_PATH` / `IPSEC_POLICY_PATH` /
`IPSEC_ACTIVE_PATH` / `IPSEC_MODE_CONFIG_PATH` / `VRRP_PATH` /
`PING_COMMAND` / `TRACEROUTE_COMMAND` / `FETCH_COMMAND` / `EMAIL_PATH` /
`BANDWIDTH_TEST_COMMAND` / `NETWATCH_PATH` /
`IP_ADDRESS_PATH` / `IP_POOL_PATH` / `DHCP_SERVER_PATH` /
`DHCP_NETWORK_PATH` / `DHCP_LEASE_PATH` / `DHCP_CLIENT_PATH` / `DHCP_RELAY_PATH` /
`PPPOE_CLIENT_PATH` / `PPPOE_SERVER_PATH` / `PPP_SECRET_PATH` / `PPP_PROFILE_PATH` /
`PPP_ACTIVE_PATH` / `LTWOTP_SERVER_PATH` / `LTWOTP_CLIENT_PATH` /
`SSTP_SERVER_PATH` / `SSTP_CLIENT_PATH` / `OVPN_SERVER_PATH` /
`OVPN_CLIENT_PATH` / `HOTSPOT_PATH` / `HOTSPOT_PROFILE_PATH` /
`HOTSPOT_USER_PATH` / `HOTSPOT_ACTIVE_PATH` / `HOTSPOT_BINDING_PATH` /
`WALLED_GARDEN_PATH` / `DNS_PATH` / `DNS_STATIC_PATH` / `DNS_ADLIST_PATH` /
`DNS_CACHE_PATH` /
`SYSTEM_PACKAGE_PATH` / `SYSTEM_UPDATE_PATH` / `SYSTEM_ROUTERBOARD_PATH` /
`SYSTEM_RESOURCE_PATH` / `SYSTEM_IDENTITY_PATH` / `SCHEDULER_PATH` /
`SCRIPT_PATH` /
`USER_PATH` / `USER_GROUP_PATH` / `USER_ACTIVE_PATH` / `SERVICE_PATH` /
`CERTIFICATE_PATH` / `CLOCK_PATH` / `NTP_CLIENT_PATH` / `FILE_PATH` /
`DISK_PATH` /
`WIFI_PATH` / `WIFI_REGISTRATION_PATH` /
`CAPSMAN_PATH` / `CAPSMAN_REGISTRATION_PATH` / `CAPSMAN_REMOTE_PATH` /
`WIFI_CAPSMAN_PATH` / `WIFI_CAP_PATH` /
`CLOUD_PATH` / `SNMP_PATH` / `SNMP_COMMUNITY_PATH` / `RADIUS_PATH` /
`SYSTEM_HEALTH_PATH` / `CONTAINER_PATH` /
`LOG_PATH` /
`LOGGING_PATH` / `LOGGING_ACTION_PATH` for use with the generic verbs.

Input validation happens before anything reaches the router: IP
addresses and CIDR networks are parsed with the stock `ipnet` module,
MAC addresses and DNS server lists are checked and normalized, and
`setupDhcp` verifies that gateway and pool range actually lie inside the
network.

## Layout

```
src/routeros.j        the module: preamble, use/import, include statements
src/routeros_test.j   the white-box test overlay: use testing + include statements
src/topics/           one implementation file and one _test file per topic
docs/                  per-topic guides
examples/              one runnable example per topic
```

`src/routeros.j` holds the `use`/`import` lines and `include`
statements that splice in the topic files —
`src/topics/core.j` (connection, generic verbs, shared helpers),
`interfaces`, `interfacelist`, `lte`, `ethernet`, `bonding`, `bridges`,
`switch`,
`vlans`, `firewall`, `raw`, `nat`, `addresslist`, `mangle`, `contrack`,
`ip`, `arp`, `neighbor`, `dhcp`, `ppp`, `l2tp`, `sstp`, `ovpn`, `hotspot`, `dns`,
`routing`, `upnp`, `trafficflow`, `queues`, `wireless`,
`wifi` (wave2), `capsman`, `wireguard`, `eoip`, `gre`, `ipsec`, `vrrp`,
`tools`, `netwatch`, `scheduler`, `script`, `users`, `services`,
`certificates`, `clock`, `files`, `disk`, `cloud`, `snmp`, `radius`,
`health`, `container`, `log`, and `system`. Since
`include` is a textual splice, the module boundary (and every `export`)
is `src/routeros.j` itself; consumers only ever
`import "./src/routeros.j"`. The topic files are not standalone
modules.

The tests mirror that structure: `src/routeros_test.j` holds
`use testing;` and splices in one `src/topics/<topic>_test.j`
per implementation topic, so a topic's code and its tests sit next to
each other.

Per-topic guides with worked examples live in the
[docs index](README.md).

## Tests

```sh
jennifer test src/routeros_test.j
```

The white-box overlay covers everything network-free: path normalization,
validation (names, ids, ports, port specs, actions, protocols), reply-row
folding into the typed structs, the rule builder's value semantics, and the
rendering of rules into RouterOS attribute maps. Functions that need a live
router are thin compositions of those tested helpers over `mikrotik.run` /
`mikrotik.print`.

## Requirements

- The default `jennifer` binary (the `mikrotik` transport needs `net`;
  `jennifer-tiny` stubs it).
- RouterOS with the API service enabled (`/ip/service` — `api` on 8728 or
  `api-ssl` on 8729). Login works on 6.43+ and v7 out of the box, with the
  MD5 fallback for older routers handled by the transport.
