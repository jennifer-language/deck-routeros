# Ethernet ports

File: `src/topics/ethernet.j`. Path: `/interface/ethernet`
(`ETHERNET_PATH`).

## Background

This is the physical layer: the copper (or SFP) ports themselves.
Everything else - bridges, VLANs, addresses - rides on top of a link
that has to come up first, at the right speed and duplex. Two facts do
most of the explaining here:

1. **Speed and duplex are negotiated.** Both ends advertise what they
   can and agree on the best match. That works so well that the only
   reason to interfere is a link partner that cannot negotiate - and if
   you force one side, you must force the other identically, or you get
   a *duplex mismatch*: the link comes up fine and then crawls, with
   errors under load. It is the classic "network is slow" root cause.
2. **A port serving a bridge is a slave.** Most of its own settings
   stop mattering; configure the bridge instead.

On PoE-capable models the port also powers the device at the far end -
which makes the PoE mode a remote power switch.

## Structs

```jennifer
mt.EthernetPort {
    id, name, defaultName,   # defaultName is the stable factory name
    mac, mtu,
    autoNegotiation,         # bool
    poeOut,                  # "auto-on" / "forced-on" / "off", "" = no PoE
    running, slave, disabled, comment
}
mt.LinkStatus {
    name, up, status,        # up = status == "link-ok"
    rate, fullDuplex,        # what was actually negotiated
    autoNegotiation          # "done" / "incomplete" / "disabled"
}
```

## Functions

| Function | Purpose |
|---|---|
| `ethernetPorts(c)` → `list of EthernetPort` | all physical ports |
| `ethernetPortByName(c, name)` → `EthernetPort` | one port |
| `linkStatus(c, name)` → `LinkStatus` | measure the link right now |
| `forceEthernetLink(c, name, speed, fullDuplex)` | pin speed/duplex (both ends!) |
| `autoNegotiateEthernet(c, name)` | back to the healthy default |
| `setEthernetMtu(c, name, mtu)` | change the MTU (68-65535) |
| `setPoe(c, name, mode)` | PoE: `auto-on` / `forced-on` / `off` |

Enable/disable, rename, and comment work through the interface topic
(`disableInterface` etc.) - ethernet ports are interfaces too.

## Examples

The "why is it slow" check across all ports:

```jennifer
def ports as list of mt.EthernetPort init mt.ethernetPorts($c);
for (def p in $ports) {
    if ($p.running) {
        def ls as mt.LinkStatus init mt.linkStatus($c, $p.name);
        io.printf("%s: %s %s duplex=%t\n", $p.name, $ls.status, $ls.rate, $ls.fullDuplex);
    }
}
```

A stubborn industrial device that cannot negotiate:

```jennifer
mt.forceEthernetLink($c, "ether4", "100Mbps", true);
# the device end must be set to 100/full as well!
# ... and back to normal later:
mt.autoNegotiateEthernet($c, "ether4");
```

Power-cycle a hung PoE access point from your desk:

```jennifer
mt.setPoe($c, "ether5", "off");
# give it a few seconds (e.g. via your own loop or scheduler)
mt.setPoe($c, "ether5", "auto-on");
```

Jumbo frames towards a storage network:

```jennifer
mt.setEthernetMtu($c, "ether3", 9000);
# every device on that path must agree on 9000, and the port's
# hardware limit (l2mtu) caps it - the router refuses what the
# chip cannot do.
```

## Pitfalls

- **Never force just one end.** Duplex mismatch does not break the
  link; it breaks the *throughput*, which is far harder to spot. When
  in doubt: `autoNegotiateEthernet` on both sides.
- `linkStatus` measures; `ethernetPorts` reads configuration. A port
  configured for auto-negotiation may still be *down* - check `up`.
- A `slave == true` port belongs to a bridge; its speed/duplex still
  matter (physical layer), but addresses and most protocols live on
  the bridge.
- `setPoe(..., "forced-on")` powers the port even with nothing
  detected - fine for odd devices that fail detection, risky for
  everything else. Prefer `auto-on`.
- Renamed ports keep their `defaultName` ("ether1") - use it to find
  the physical port a creative admin renamed.

## Related

- [interfaces.md](interfaces.md) (enable/disable/rename/comment),
  [bridges.md](bridges.md) (slave ports), [tools.md](tools.md)
  (bandwidth test to verify a link's real throughput).
