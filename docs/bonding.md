# Bonding (link aggregation)

File: `src/topics/bonding.j`. Path: `/interface/bonding`
(`BONDING_PATH`).

## Background

A bond makes several physical links act as one logical interface. Two
motivations, two modes:

- **Throughput + redundancy** with a managed switch: LACP
  (`802.3ad`, constant `BOND_LACP`). Both ends negotiate the bundle;
  if a cable dies, the bundle shrinks and keeps working. Important
  expectation management: one *flow* (one download, one backup stream)
  still travels one link - LACP raises total capacity across many
  flows, not the speed of a single transfer.
- **Pure redundancy** with any switch: active-backup
  (`BOND_ACTIVE_BACKUP`). One link carries traffic, the others stand
  by; no switch cooperation needed, which also makes it the right mode
  when the two cables go to two *different* switches.

The bond is an interface like any other afterwards - typically it goes
straight into the LAN bridge, or carries VLANs.

## Struct

```jennifer
mt.Bond {
    id, name,
    slaves,               # member interfaces, comma-separated
    mode, primary,        # primary only meaningful in active-backup
    transmitHashPolicy,   # how 802.3ad spreads flows
    mac, mtu, running, disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `addLacpBond(c, name, slaves)` → id | 802.3ad aggregation (switch must match) |
| `addFailoverBond(c, name, slaves, primary)` → id | active-backup redundancy |
| `addBond(c, name, slaves, mode)` → id | any of the seven modes |
| `bonds(c)` → `list of Bond` | all bonds |
| `bondByName(c, name)` → `Bond` | one bond |
| `setBondSlaves(c, name, slaves)` | change membership |
| `removeBond(c, name)` | delete (members become plain ports) |
| `enableBond(c, name)` / `disableBond(c, name)` | switch on / off |

Slave lists are validated before anything is sent: at least two
distinct, existing interfaces, none already serving another bond; a
failover bond's `primary` must be one of its slaves.

## Examples

A two-cable LACP trunk to the core switch, feeding the LAN bridge:

```jennifer
mt.addLacpBond($c, "bondtrunk", "ether1,ether2");
mt.addBridgePort($c, "brlan", "bondtrunk");
# on the switch: create a LAG/port-channel with LACP on those two ports
```

Redundant uplink across two independent switches (no LACP possible):

```jennifer
mt.addFailoverBond($c, "bonduplink", "ether1,ether2", "ether1");
mt.addIpAddress($c, "10.0.0.2/24", "bonduplink");
```

Grow a bundle later:

```jennifer
mt.setBondSlaves($c, "bondtrunk", "ether1,ether2,ether3");
```

Check the bundle's health:

```jennifer
def b as mt.Bond init mt.bondByName($c, "bondtrunk");
io.printf("%s (%s) over %s running=%t\n", $b.name, $b.mode, $b.slaves, $b.running);
# per-member link state comes from the ethernet topic:
def ls as mt.LinkStatus init mt.linkStatus($c, "ether1");
io.printf("member ether1: %s at %s\n", $ls.status, $ls.rate);
```

## Pitfalls

- **LACP needs both ends configured.** A bond in `802.3ad` against a
  switch without a matching LAG stays down (that is LACP protecting you
  from a loop). For "it must just work with any switch", use
  `addFailoverBond`.
- **One flow, one link.** A single large transfer over a 2×1G LACP
  bond still peaks at 1G. More parallel flows spread better; the
  spread policy is `transmit-hash-policy` (generic `set`, e.g.
  `"layer-3-and-4"`).
- Member ports must be *plain*: not bridge ports, not carrying
  addresses. routeros checks they exist and are not in another bond;
  clearing other roles is on you.
- `running == true` means *at least one* member is up - a degraded
  LACP bundle still shows running. Check the members' `linkStatus`
  for the full picture.
- Removing a bond orphans whatever referenced it (bridge port,
  addresses) - tear those down first.

## Related

- [ethernet.md](ethernet.md) (per-member link state),
  [bridges.md](bridges.md) (where a trunk bond usually ends up),
  [vlans.md](vlans.md) (VLANs on top of a bond).
