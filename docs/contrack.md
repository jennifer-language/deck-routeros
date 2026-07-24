<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# Connection tracking

File: `src/topics/contrack.j`. Paths:
`/ip/firewall/connection/tracking` (`CONNTRACK_SETTINGS_PATH`),
`/ip/firewall/connection` (`CONNECTION_PATH`).

## Background

Connection tracking is the state behind stateful firewalling and NAT —
every flow the router has seen, with its addresses, protocol, and (for
TCP) state. Reading it answers operational questions the config alone
cannot: *what is this device actually talking to*, *is the table
filling up*, *why is that flow stuck*.

## Structs

```jennifer
mt.ConntrackSettings { enabled, totalEntries, maxEntries }   # ints
mt.Connection { id, protocol, srcAddress, dstAddress, tcpState, timeout, connectionMark }
```

## Functions

| Function | Purpose |
|---|---|
| `conntrackSettings(c)` → `ConntrackSettings` | fill level and capacity |
| `connections(c)` → `list of Connection` | the whole table (large) |
| `connectionsFor(c, address)` | flows involving one host |
| `dropConnectionsFor(c, address)` → count | reset a host's flows |

## Examples

Is the table healthy?

```jennifer
def s as mt.ConntrackSettings init mt.conntrackSettings($c);
io.printf("%d of %d connections (%d%% full)\n",
    $s.totalEntries, $s.maxEntries, $s.totalEntries * 100 // $s.maxEntries);
```

What is one device doing?

```jennifer
def conns as list of mt.Connection init mt.connectionsFor($c, "192.168.88.50");
for (def con in $conns) {
    io.printf("%s %s -> %s %s\n", $con.protocol, $con.srcAddress, $con.dstAddress, $con.tcpState);
}
```

Cut a host off instantly (without a firewall rule), or clear flows stuck
after a routing change:

```jennifer
def n as int init mt.dropConnectionsFor($c, "192.168.88.55");
io.printf("dropped %d connections\n", $n);
```

## Pitfalls

- **The table is huge on a busy router** — `connections(c)` may return
  thousands of rows. Prefer `connectionsFor`.
- Dropping connections is not blocking — the host can immediately open
  new ones. To *keep* it out, add a firewall rule
  ([firewall.md](firewall.md)) or an address-list drop
  ([addresslist.md](addresslist.md)); drop the connections to make the
  block take effect on existing flows.
- A near-full table (`totalEntries` approaching `maxEntries`) drops new
  connections — a symptom of a scan, a P2P host, or a too-small table.
- NAT'd flows appear in translated form; the same flow may show its
  original and NAT'd addresses.

## Related

- [firewall.md](firewall.md), [nat.md](nat.md),
  [mangle.md](mangle.md) (connection marks appear here).
