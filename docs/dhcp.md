# DHCP: server, leases, and the WAN client

File: `src/topics/dhcp.j`. Paths: `/ip/pool`, `/ip/dhcp-server`,
`/ip/dhcp-server/network`, `/ip/dhcp-server/lease`, `/ip/dhcp-client`
(`IP_POOL_PATH`, `DHCP_SERVER_PATH`, `DHCP_NETWORK_PATH`,
`DHCP_LEASE_PATH`, `DHCP_CLIENT_PATH`).

## Background

DHCP has two sides on a router:

- **Server** (LAN side): hands addresses, gateway, and DNS to your
  clients. RouterOS needs *three* objects for this - an address pool
  (the range to hand out), the server itself (bound to an interface),
  and a network entry (gateway + DNS the clients are told). Forgetting
  one of the three is the classic beginner failure; routeros creates
  them together.
- **Client** (WAN side): asks the ISP for the router's own public
  address. See "WAN" below.

## DHCP server

```jennifer
# the interface needs an address inside the network first
mt.addIpAddress($c, "192.168.77.1/24", "brlan");

mt.setupDhcp($c, "dhcplan", "brlan",
    "192.168.77.0/24",       # the network
    "192.168.77.1",          # gateway told to clients (the router itself)
    "192.168.77.10",         # range start
    "192.168.77.199",        # range end
    "192.168.77.1");         # DNS told to clients (comma list allowed)
```

Everything is cross-checked before anything is created: the gateway and
both range ends must lie *inside* the network, the interface must
exist, DNS entries must be IP addresses. The pool shares the server's
name so the whole thing can be undone:

```jennifer
mt.teardownDhcp($c, "dhcplan", "192.168.77.0/24");
```

(each of the three pieces is removed if present - a half-finished setup
tears down too).

Other server-side functions: `dhcpServers(c)` → `list of DhcpServer`.

## Leases and reservations

```jennifer
# who is on the network right now?
def leases as list of mt.DhcpLease init mt.dhcpLeases($c);
for (def l in $leases) {
    io.printf("%s -> %s (%s) %s\n", $l.address, $l.mac, $l.hostName, $l.status);
}

# always give the printer the same address
mt.addStaticLease($c, "192.168.77.50", "AA:BB:CC:DD:EE:FF", "printer");

# and take the reservation away again
mt.removeLeaseByMac($c, "AA:BB:CC:DD:EE:FF");
```

`DhcpLease.dynamic` distinguishes an automatic lease from a static
reservation. MAC addresses are validated (six hex pairs) and uppercased
for you.

## WAN: the DHCP client

```jennifer
mt.setupWan($c, "ether1");                  # defaults: ISP route + ISP DNS
mt.addMasquerade($c, "ether1", "lan to internet");

def wan as mt.DhcpClient init mt.wanStatus($c, "ether1");
if ($wan.bound) {
    io.printf("online as %s via %s, lease renews in %s\n",
        $wan.address, $wan.gateway, $wan.expiresAfter);
}
```

`setupWan` is idempotent (an existing client on the interface is
reused). `setupWanWith(c, iface, usePeerDns, addDefaultRoute)` opts out
of adopting the ISP's DNS or route - useful for a backup uplink whose
route you manage with `addRouteWithDistance` (see
[routing.md](routing.md)). Also: `renewWan(c, iface)` (fresh lease),
`dhcpClients(c)`, `removeDhcpClient` / `enableDhcpClient` /
`disableDhcpClient(c, iface)`.

`DhcpClient.addDefaultRoute` stays a string because RouterOS allows
three values (`yes` / `no` / `special-classless`).

## Pitfalls

- **The interface must have an address inside the served network** -
  clients are told a gateway they can only reach if the router is
  actually there. `setupDhcp`'s docblock reminds you; the snippet above
  shows the order.
- One DHCP server per interface; RouterOS refuses a second.
- A static lease for a device with an *active* dynamic lease takes
  effect at the next renewal, not instantly.
- On the WAN side, `bound == false` with status `searching...` usually
  means the ISP link is down or the modem is not bridging.
- Do not run a DHCP server on the WAN interface. RouterOS will happily
  let you annoy your ISP.

## Related

- [ip.md](ip.md), [nat.md](nat.md), [ppp.md](ppp.md) (PPPoE instead of
  DHCP WAN), [dns.md](dns.md) (the router as the LAN's resolver).
