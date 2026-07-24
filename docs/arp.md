# The ARP table

File: `src/topics/arp.j`. Path: `/ip/arp` (`ARP_PATH`).

## Background

ARP is how a router maps IP addresses to hardware (MAC) addresses on
its connected networks. The table under `/ip/arp` is therefore two
things at once:

1. **A live inventory** - every device the router recently exchanged
   packets with shows up, which makes it the quickest honest answer to
   "who is on my LAN right now".
2. **A security lever** - entries can be pinned *statically*, and an
   interface switched to `arp=reply-only` then only talks to pinned
   devices at all.

Entries are *dynamic* (learned, they age out) or *static* (yours, they
stay). An entry with `complete == false` is an address the router tried
to resolve and got no answer for - typically an offline device.

## Struct

```jennifer
mt.ArpEntry {
    id, address, mac,        # mac is "" while unresolved
    interfaceName,
    dynamic,                 # learned vs. pinned
    complete,                # MAC actually known
    published,               # router answers ARP for it (proxy ARP)
    disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `arpTable(c)` → `list of ArpEntry` | the whole table |
| `arpTableOn(c, interfaceName)` | one interface's entries |
| `macForAddress(c, address)` → string | IP → MAC; `""` on a miss (a miss is normal) |
| `addressesForMac(c, mac)` → `list of string` | MAC → IPs, case-insensitive |
| `addStaticArp(c, address, mac, interfaceName)` → id | pin a binding |
| `removeArpEntry(c, address)` | unpin, or clear a stale dynamic entry |
| `flushArp(c, interfaceName)` → count | drop all dynamic entries there |

## Examples

Who is on the LAN, and are they resolved?

```jennifer
def neighbours as list of mt.ArpEntry init mt.arpTableOn($c, "brlan");
for (def n in $neighbours) {
    io.printf("%s -> %s dynamic=%t complete=%t\n",
        $n.address, $n.mac, $n.dynamic, $n.complete);
}
```

Find a device both ways:

```jennifer
def mac as string init mt.macForAddress($c, "192.168.88.50");
if ($mac == "") {
    io.printf("the printer has not talked to the router recently\n");
}

def addrs as list of string init mt.addressesForMac($c, "AA:BB:CC:DD:EE:FF");
for (def a in $addrs) {
    io.printf("that device holds %s\n", $a);
}
```

The locked-down LAN - only pinned devices may talk:

```jennifer
# pin every allowed device...
mt.addStaticArp($c, "192.168.88.50", "AA:BB:CC:DD:EE:FF", "brlan");
mt.addStaticArp($c, "192.168.88.51", "11:22:33:44:55:66", "brlan");
# ...then switch the interface to reply-only (generic verb - it is an
# interface property, not an ARP-table one):
mt.set($c, mt.INTERFACE_PATH,
    mt.idByName($c, mt.INTERFACE_PATH, "brlan"), {"arp": "reply-only"});
```

After swapping a device's hardware (same IP, new MAC):

```jennifer
mt.removeArpEntry($c, "192.168.88.50");   # clears the stale binding
# a static entry must be re-pinned with the new MAC afterwards
```

## Pitfalls

- **ARP only sees layer-2 neighbours.** Devices behind another router
  (or on a non-connected network) never appear; that is routing, not a
  fault.
- The table is a *cache*: an offline device ages out after a few
  minutes. Absence proves nothing; presence proves recent traffic.
- `arp=reply-only` without a complete set of static entries cuts off
  everyone you forgot - pin first, switch second, and keep the router's
  own management path in mind.
- Static ARP does not stop a determined spoofer on an open network -
  it protects the *router's* view, not the switch fabric.
- DHCP can create ARP entries for its leases (`add-arp` on the DHCP
  server, generic verbs) - handy together with `arp=reply-only` on the
  DHCP interface.

## Related

- [dhcp.md](dhcp.md) (leases pair naturally with static ARP),
  [interfaces.md](interfaces.md) (the `arp` interface property),
  [wireless.md](wireless.md) (`wifiClients` is the WiFi flavor of
  "who is connected").
