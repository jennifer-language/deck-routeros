<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# Firewall raw (pre-conntrack)

File: `src/topics/raw.j`. Path: `/ip/firewall/raw` (`RAW_PATH`).

## Background

The raw table runs **before connection tracking** - earlier and cheaper
than the filter table. Two jobs:

1. **Drop garbage as early as possible** - spoofed sources, bogons
   (addresses that should never appear on the internet), the flat part
   of a flood. Dropping here spares the conntrack table and CPU.
2. **`notrack`** - exempt chosen traffic (very high-volume, or something
   that must not be tracked) from the connection table entirely.

Raw has chains `prerouting` (incoming - the usual choice) and `output`.
It reuses this module's firewall builder as the matcher.

## Struct

```jennifer
mt.RawRule { id, chain, action, protocol, srcAddress, dstAddress,
             srcAddressList, inInterfaceList, comment, disabled }
```

## Functions

| Function | Purpose |
|---|---|
| `rawRules(c)` → `list of RawRule` | all raw rules |
| `addRawRule(c, rule)` → id | create from a firewall-builder matcher |
| `dropRawAddressList(c, listName, comment)` → id | drop a blocklist early |
| `removeRawRule(c, id)` / `removeRawRuleByComment(c, comment)` | delete |
| `moveRawRule(c, id, beforeId)` | reorder; `""` sends it to the bottom |
| `moveRawRuleByComment(c, comment, beforeComment)` | the same, by comment handles |

Build the matcher with `firewallRule(chain, action)` + the `with*`
refiners - chain `CHAIN_PREROUTING`/`CHAIN_OUTPUT`, action
`accept`/`drop`/`ACTION_NOTRACK`.

## Examples

Drop bogons from the WAN at the cheapest point (pairs with
[addresslist.md](addresslist.md) for the list and
[interfacelist.md](interfacelist.md) for `WAN`):

```jennifer
def r as mt.FirewallRule init mt.firewallRule(mt.CHAIN_PREROUTING, mt.ACTION_DROP);
$r = mt.withInInterfaceList($r, "WAN");
$r = mt.withSrcAddressList($r, "bogons");
$r = mt.withComment($r, "drop bogons from WAN");
mt.addRawRule($c, $r);
```

Or the shortcut for a whole-list drop:

```jennifer
mt.dropRawAddressList($c, "bogons", "drop bogons early");
```

Exempt heavy multicast from connection tracking:

```jennifer
def n as mt.FirewallRule init mt.firewallRule(mt.CHAIN_PREROUTING, mt.ACTION_NOTRACK);
$n = mt.withDstAddress($n, "224.0.0.0/4");
$n = mt.withComment($n, "do not track multicast");
mt.addRawRule($c, $n);
```

## Pitfalls

- **Raw sees untracked packets** - you can't match `connection-state`
  here (that is what tracking provides, and it hasn't run yet). Match on
  addresses, ports, interfaces, and address lists.
- **Order and specificity matter** - a broad raw drop above a needed
  accept blocks it, and rules append. Either build the `accept` first,
  or repair the order afterwards with `moveRawRule(c, id, beforeId)` /
  `moveRawRuleByComment(c, comment, beforeComment)` (pass `""` as the
  destination to send a rule to the bottom).
- `notrack` disables NAT and stateful filtering for that traffic - use
  it deliberately, not as a performance dial.
- Raw drops are invisible to conntrack tools ([contrack.md](contrack.md))
  precisely because they act before tracking - that is the point, but it
  means you debug them from counters, not the connection table.

## Related

- [firewall.md](firewall.md) (the shared builder + interface-list
  matchers), [addresslist.md](addresslist.md),
  [interfacelist.md](interfacelist.md), [contrack.md](contrack.md).
