# Mangle: packet marking

File: `src/topics/mangle.j`. Path: `/ip/firewall/mangle`
(`MANGLE_PATH`). Chains: `CHAIN_PREROUTING` / `CHAIN_POSTROUTING` (plus
the familiar input/forward/output).

## Background

Mangle rules do not accept or drop anything - they *label* traffic, and
other subsystems act on the labels:

- a **packet mark** lets queues treat a kind of traffic specially
  ("VoIP first", "backups capped") regardless of addresses;
- a **routing mark** sends traffic to a different routing table -
  policy routing, e.g. "the guest subnet uses the backup uplink";
- **change-mss** is not a mark but lives here too: it repairs TCP over
  small-MTU links (PPPoE, tunnels).

The canonical marking pattern is a two-step, because per-packet
matching is expensive: mark the *connection* once (when it is new),
then cheaply mark every *packet* of marked connections.
`setupPacketMark` builds exactly that pair.

Instead of a second builder, mangle reuses the firewall topic's
`FirewallRule` as its **matcher**: build the match with `firewallRule`
and the `with*` refiners - the rule's chain is honored, its action is
replaced by the marking actions.

## Struct

```jennifer
mt.MangleRule {
    id, chain, action,
    newConnectionMark, newPacketMark, newRoutingMark, newMss,
    connectionMark, packetMark,          # what the rule matches on
    protocol, srcAddress, dstAddress, dstPort,
    inInterface, outInterface,
    passthrough, disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `setupPacketMark(c, markName, matcher)` → id | the connection+packet mark pair |
| `removePacketMark(c, markName)` | remove the pair |
| `markRoutingFor(c, markName, srcAddress)` → id | policy routing for a host/subnet |
| `removeRoutingMark(c, markName, srcAddress)` | undo it |
| `clampTcpMss(c, interfaceName)` | MSS clamp, both directions, idempotent |
| `removeTcpMssClamp(c, interfaceName)` | undo it |
| `mangleRules(c)` → `list of MangleRule` | read everything back |

All setup helpers are idempotent, keyed by their comment convention
(`"mark: <name> (...)"`, `"route mark: ..."`, `"mss clamp: ..."`) -
re-running a provisioning script never duplicates rules.

## Example: VoIP gets priority

Mark SIP/RTP traffic, then point a queue at the mark:

```jennifer
def m as mt.FirewallRule init mt.firewallRule(mt.CHAIN_PREROUTING, mt.ACTION_ACCEPT);
$m = mt.withProtocol($m, "udp");
$m = mt.withDstPort($m, "5060-5200");
mt.setupPacketMark($c, "voip", $m);

# queues match the packet mark instead of addresses (generic set on
# an existing simple queue):
mt.limitBandwidth($c, "qvoip", "192.168.88.0/24", "0", "0");
mt.set($c, mt.QUEUE_SIMPLE_PATH,
    mt.idByName($c, mt.QUEUE_SIMPLE_PATH, "qvoip"),
    {"packet-marks": "voip", "priority": "1/1"});
```

## Example: one subnet uses the backup uplink

```jennifer
# v7: the routing table must exist first (generic verbs)
mt.add($c, "/routing/table", {"name": "backupisp", "fib": ""});
# a default route inside that table
mt.add($c, mt.ROUTE_PATH, {"dst-address": "0.0.0.0/0",
    "gateway": "198.51.100.1", "routing-table": "backupisp"});
# and the mark that sends the guest net there
mt.markRoutingFor($c, "backupisp", "10.30.0.0/24");
```

## Example: the PPPoE page-hang fix

```jennifer
mt.clampTcpMss($c, "pppoewan");
```

## Pitfalls

- **A mark alone does nothing** - it needs a consumer: a queue matching
  the packet mark, a routing table for the routing mark. Set those up
  too, or the mangle rules are just bookkeeping.
- Fasttrack bypasses mangle for established connections on a default
  firewall (same story as with queues - see [queues.md](queues.md)).
  If marks "don't work", that is the first suspect.
- Queue marks belong in `CHAIN_PREROUTING` (before routing decisions);
  marking in the wrong chain silently matches nothing for half the
  traffic directions.
- `markRoutingFor` traffic skips the main table entirely - if the
  marked table has no route for a destination, that destination is
  unreachable for the marked source. Give the table a default route.
- `passthrough` semantics: the packet-mark rule stops processing
  (`passthrough=no`) so later mangle rules do not re-mark; the
  connection rule passes through. `setupPacketMark` sets both
  correctly.

## Related

- [firewall.md](firewall.md) (the shared matcher builder),
  [queues.md](queues.md) (consuming packet marks),
  [routing.md](routing.md) (tables and routes),
  [ppp.md](ppp.md) / [gre.md](gre.md) (where MSS clamping matters).
