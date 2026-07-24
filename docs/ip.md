# IP addresses

File: `src/topics/ip.j`. Path: `/ip/address` (`IP_ADDRESS_PATH`).

## Background

An interface takes part in an IP network by carrying an address *with a
prefix length*: `192.168.88.1/24` means "I am 192.168.88.1, and
everything in 192.168.88.0-255 is directly reachable here". The prefix
is not decoration - it tells the router how big the network is, so
routeros refuses an address without one rather than letting RouterOS
guess.

Addresses can be *static* (you set them) or *dynamic* (a DHCP client or
PPPoE session put them there; those cannot be removed by hand).

## Struct

```jennifer
mt.IpAddress {
    id,
    address,          # "192.168.88.1/24"
    network,          # "192.168.88.0" - derived by RouterOS
    interfaceName,
    dynamic,          # true: DHCP/PPP assigned it
    disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `ipAddresses(c)` → `list of IpAddress` | every address, static and dynamic |
| `addIpAddress(c, address, interfaceName)` → id | assign an address (CIDR required) |
| `removeIpAddress(c, address)` | remove by exact address string |

`addIpAddress` validates the CIDR via real parsing (`ipnet`) and checks
the interface exists.

## Examples

Give the LAN bridge its gateway address:

```jennifer
mt.addIpAddress($c, "192.168.88.1/24", "brlan");
```

List everything with provenance:

```jennifer
def addrs as list of mt.IpAddress init mt.ipAddresses($c);
for (def a in $addrs) {
    io.printf("%s on %s dynamic=%t %s\n",
        $a.address, $a.interfaceName, $a.dynamic, $a.comment);
}
```

Renumber an interface (remove old, add new):

```jennifer
mt.removeIpAddress($c, "192.168.88.1/24");
mt.addIpAddress($c, "10.0.10.1/24", "brlan");
```

## Pitfalls

- **The prefix is mandatory.** `"192.168.88.1"` is rejected with a
  message telling you to write `"192.168.88.1/24"` - a bare address
  would otherwise become a /32 with no reachable network.
- **Renumbering the interface your session runs over** disconnects you
  the moment the old address goes; do it from another path (or accept
  the reconnect).
- `removeIpAddress` matches the address string *exactly as listed* -
  `"192.168.88.1/24"`, not `"192.168.88.1"`.
- Dynamic addresses (from [dhcp.md](dhcp.md) WAN or [ppp.md](ppp.md))
  disappear with their session; do not try to manage them here.
- Two interfaces in the same subnet (overlapping networks) confuse
  routing; RouterOS allows it, your network will not enjoy it.

## Related

- [bridges.md](bridges.md) - the LAN address belongs on the bridge.
- [dhcp.md](dhcp.md) - serve the network you just addressed.
- [routing.md](routing.md) - addresses create "connected" routes
  automatically.
