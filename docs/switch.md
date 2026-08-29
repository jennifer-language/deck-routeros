<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# Switch chip (hardware offload)

File: `src/topics/switch.j`. Paths: `/interface/ethernet/switch`
(`ETHERNET_SWITCH_PATH`), `/interface/ethernet/switch/host`
(`ETHERNET_SWITCH_HOST_PATH`). Plus the `hardwareOffload` field and
`setBridgePortHardwareOffload` in the [bridges](bridges.md) topic.

## Background

Many MikroTik boards (the CRS switches, hEX/RB models) have a **switch
chip** that forwards frames between ports in hardware at wire speed,
without the CPU. The important thing to understand on RouterOS v7: **you
do not configure the chip directly** for the common case. You build a
[VLAN-aware bridge](vlans.md) (`enableVlanFiltering` + `addBridgeVlan` +
`setPortPvid`), and when the configuration is offloadable, RouterOS
pushes it down to the switch chip automatically. The legacy per-chip
config (`/interface/ethernet/switch/vlan`, `.../rule`) is expert,
hardware-specific, and superseded - this topic deliberately does not
wrap it.

What this topic gives you is the ability to **see and verify** offload:
does the board have a chip, is the `hw` flag on per port, and is the
chip actually forwarding (its MAC table populated).

## Structs

```jennifer
mt.SwitchChip { id, name, kind }                 # kind = the chip model
mt.SwitchHost { mac, ports, vlanId, dynamic }    # the chip's hardware MAC table
```

The bridge port carries the intent flag:
`mt.BridgePort.hardwareOffload` (the `hw` setting).

## Functions

| Function | Purpose |
|---|---|
| `switchChips(c)` → `list of SwitchChip` | the chip(s); empty on a pure-CPU board |
| `switchHosts(c)` → `list of SwitchHost` | the chip's hardware MAC table |
| `setBridgePortHardwareOffload(c, interfaceName, on)` | the port `hw` flag (bridges topic) |

## Example: is my VLAN-aware bridge actually accelerated?

```jennifer
# 1. does this board even have a switch chip?
def chips as list of mt.SwitchChip init mt.switchChips($c);
if (len($chips) == 0) { io.printf("pure-CPU board - no hardware offload\n"); }
for (def ch in $chips) { io.printf("switch %s (%s)\n", $ch.name, $ch.kind); }

# 2. which bridge ports are allowed to offload?
def ports as list of mt.BridgePort init mt.bridgePorts($c, "brlan");
for (def p in $ports) {
    io.printf("%s: hw=%t\n", $p.interfaceName, $p.hardwareOffload);
}

# 3. proof: the chip's hardware MAC table is populated
def hosts as list of mt.SwitchHost init mt.switchHosts($c);
io.printf("%d MACs learned in hardware\n", len($hosts));
```

Force a port to software forwarding (rarely wanted - e.g. to use a
software-only feature on it):

```jennifer
mt.setBridgePortHardwareOffload($c, "ether2", false);
```

## Pitfalls

- **`hw=yes` is intent, not proof.** RouterOS silently falls back to
  software when the bridge config isn't offloadable (certain L3
  features, some VLAN configs, mixing chips). The real check is the
  triple: `hardwareOffload == true` on the ports **and** low CPU under
  load **and** a populated `switchHosts` for your LAN's MACs.
- **A pure-CPU board** (`switchChips` empty) forwards everything in
  software - fine at its rated throughput, but there's nothing to
  offload to; don't chase a chip that isn't there.
- **Ports on different switch chips can't offload between each other** -
  traffic between them crosses the CPU. `switchChips` shows how many
  there are.
- **Turning `hw` off** on a port that was accelerated moves its traffic
  to the CPU - a quick way to pin the CPU on a busy port. Only do it
  deliberately.
- The deep per-chip config (ACL-style switch rules, port mirroring, the
  legacy hardware VLAN table) is reachable with the generic verbs on
  `/interface/ethernet/switch/*` when you genuinely need it.

## Related

- [bridges.md](bridges.md) (the VLAN-aware bridge that offloads, and the
  `hw` flag), [vlans.md](vlans.md) (the modern VLAN model),
  [ethernet.md](ethernet.md) (the ports themselves),
  [system.md](system.md) (watch CPU load to confirm offload).
