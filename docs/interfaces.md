# Interfaces

File: `src/topics/interfaces.j`. Path: `/interface` (`INTERFACE_PATH`).

## Background

`/interface` is RouterOS's master list of every interface - physical
ethernet ports (`ether1`...), and all the virtual ones other topics
create (bridges, VLANs, PPPoE sessions, WireGuard tunnels). You cannot
*create* interfaces here; you inspect and manage the ones that exist.
Two flags matter: `running` (link is up, cable plugged, radio on) and
`disabled` (administratively switched off).

## Struct

```jennifer
mt.Interface {
    id, name, kind,          # kind is RouterOS's "type": "ether", "bridge", "wlan", ...
    mac,                     # hardware address, "" for some virtual interfaces
    running, disabled,       # bools
    comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `interfaces(c)` → `list of Interface` | everything the router has |
| `interfaceByName(c, name)` → `Interface` | one interface, error if absent |
| `enableInterface(c, name)` | switch on |
| `disableInterface(c, name)` | switch off (traffic stops) |
| `renameInterface(c, current, next)` | give it a new name |
| `commentInterface(c, name, comment)` | attach/clear a note |

## Examples

Inventory with status:

```jennifer
def ifaces as list of mt.Interface init mt.interfaces($c);
for (def i in $ifaces) {
    io.printf("%s (%s) running=%t disabled=%t %s\n",
        $i.name, $i.kind, $i.running, $i.disabled, $i.comment);
}
```

Label the uplink and switch an unused port off:

```jennifer
mt.commentInterface($c, "ether1", "uplink to ISP");
mt.disableInterface($c, "ether5");
```

Check a link before relying on it:

```jennifer
def wan as mt.Interface init mt.interfaceByName($c, "ether1");
if (not $wan.running) {
    io.printf("ether1 has no link - is the cable plugged in?\n");
}
```

## Pitfalls

- **Disabling the interface you are connected through** cuts your own
  session off. routeros cannot protect you from that - check first.
- `running == false` with `disabled == false` means a layer-1 problem
  (no cable, no link partner), not a configuration problem.
- Renaming an interface does **not** update references to the old name
  in comments or external scripts; RouterOS itself updates its own
  references (firewall rules, bridge ports, ...).

## Related

- [bridges.md](bridges.md), [vlans.md](vlans.md) - create virtual
  interfaces that then appear in this list.
- [ip.md](ip.md) - put addresses on interfaces.
