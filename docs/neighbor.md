<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# Neighbor discovery

File: `src/topics/neighbor.j`. Path: `/ip/neighbor` (`NEIGHBOR_PATH`).

## Background

Network devices announce themselves on the wire — MikroTik with MNDP,
Cisco with CDP, most vendors with LLDP. The router collects those
announcements from its directly-connected segments, so `/ip/neighbor`
answers "what is plugged into this segment" without a scan: the switch
on ether2, the AP on ether5, the router upstream. Only same-segment
neighbors appear — nothing behind another router.

## Struct

```jennifer
mt.Neighbor { interfaceName, address, mac, identity, platform, board, version }
```

## Functions

| Function | Purpose |
|---|---|
| `neighbors(c)` → `list of Neighbor` | everything discovered |
| `neighborsOn(c, interfaceName)` | one interface's neighbors |

## Example

Map the rack:

```jennifer
def ns as list of mt.Neighbor init mt.neighbors($c);
for (def n in $ns) {
    io.printf("%s: %s %s (%s) at %s on %s\n",
        $n.identity, $n.platform, $n.board, $n.version, $n.address, $n.interfaceName);
}
```

Find what's on the uplink:

```jennifer
def up as list of mt.Neighbor init mt.neighborsOn($c, "ether1");
for (def n in $up) { io.printf("upstream: %s (%s)\n", $n.identity, $n.address); }
```

## Pitfalls

- **Layer-2 only:** a neighbor with no `address` was heard at layer 2
  but has no IP on this segment — normal, not an error.
- **Discovery must be enabled** on the interface for the router to hear
  (and be heard) — it is on by default, but a hardened config may
  restrict `/ip/neighbor/discovery-settings` (generic verbs); on an
  untrusted/WAN interface, turning discovery *off* is good hygiene (it
  otherwise leaks your model and version).
- Non-announcing devices (plain PCs, most servers) never appear —
  absence here doesn't mean nothing is connected. Pair with
  [arp.md](arp.md) for IP↔MAC presence.

## Related

- [arp.md](arp.md) (who has an IP here), [interfaces.md](interfaces.md),
  [services.md](services.md) (discovery is another thing to lock down on
  the WAN).
