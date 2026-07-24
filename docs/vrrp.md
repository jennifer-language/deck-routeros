# VRRP: gateway redundancy

File: `src/topics/vrrp.j`. Path: `/interface/vrrp` (`VRRP_PATH`).

## Background

A LAN's single point of failure is usually its gateway. VRRP removes
it: two (or more) routers guard one shared *virtual* address, and the
clients use that address as their gateway. At any moment exactly one
router - the **master**, the one with the highest priority - answers
for it; the others are **backups** listening to its advertisements.
When the master falls silent, the best backup takes over within
seconds, with the same IP *and the same virtual MAC*, so clients notice
nothing. No client reconfiguration, no DHCP change, no ARP confusion.

The three shared parameters:

- **vrid** (1-255): identifies the redundancy group; identical on all
  peers, unique per network segment.
- **priority** (1-254): highest wins. Give the preferred router 200 and
  the standby 100 - equal priorities make the election arbitrary.
- **the virtual address**: the same on all peers, placed on the VRRP
  interface (by convention as `/32`); each router keeps its own real
  address on the LAN besides it.

## Struct

```jennifer
mt.VrrpInterface {
    id, name, interfaceName,
    vrid, priority,          # ints
    interval, version,       # advertisement interval; VRRP v2 or v3
    preemption,              # returning higher priority takes back over
    running, backup,
    master,                  # computed: running and not backup
    disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `setupVrrp(c, name, interfaceName, vrid, priority, virtualAddress)` → id | instance + shared address, one call |
| `addVrrp(c, name, interfaceName, vrid, priority)` → id | instance only |
| `vrrpInterfaces(c)` → `list of VrrpInterface` | all instances with state |
| `vrrpByName(c, name)` → `VrrpInterface` | one instance - check `.master` |
| `setVrrpPriority(c, name, priority)` | the failover dial |
| `removeVrrp(c, name)` | instance + its virtual address(es) |
| `enableVrrp(c, name)` / `disableVrrp(c, name)` | join / leave the group |

Validation: vrid 1-255, priority 1-254 (255 is reserved by the RFC for
the address owner), the underlying interface must exist, the name must
be free, and a vrid already used on that interface is refused with the
owning instance named - the same vrid on *another* interface is fine.

## Example: a redundant gateway pair

Both routers have their own LAN address (e.g. .251 and .252); the
clients' gateway is the virtual .254:

```jennifer
# --- router A (preferred) ---
mt.setupVrrp($c, "vrrplan", "brlan", 10, 200, "192.168.88.254/32");

# --- router B (standby, its own client) ---
# mt.setupVrrp($cb, "vrrplan", "brlan", 10, 100, "192.168.88.254/32");
```

Point DHCP clients at the virtual gateway (see [dhcp.md](dhcp.md) -
the `gateway` parameter of `setupDhcp` becomes `192.168.88.254`).

Who is master right now?

```jennifer
def v as mt.VrrpInterface init mt.vrrpByName($c, "vrrplan");
if ($v.master) {
    io.printf("this router answers for the gateway\n");
} elseif ($v.backup) {
    io.printf("standing by, priority %d\n", $v.priority);
}
```

Graceful maintenance - hand the role away before rebooting:

```jennifer
mt.setVrrpPriority($c, "vrrplan", 50);   # peer takes over within seconds
# ... maintain, reboot, verify ...
mt.setVrrpPriority($c, "vrrplan", 200);  # with preemption on, the role returns
```

## Pitfalls

- **Redundancy needs redundant everything.** A VRRP pair behind one
  switch, one uplink, or one power strip moves the single point of
  failure; it does not remove it.
- **Only the gateway fails over.** Connection state does not: NAT
  table and DHCP leases live per router. Run DHCP on both (split
  scopes, or leases long enough to survive), and expect long-lived
  connections to reset on failover.
- Equal priorities work but make the election arbitrary - always give
  the preferred router the clearly higher number.
- The firewall must allow VRRP (protocol `vrrp`, multicast 224.0.0.18)
  between the peers on the LAN - a strict input chain silently breaks
  the election and BOTH routers claim master ("split brain"). The
  `vrrp` protocol is in the firewall builder's known list.
- Both peers should agree on the VRRP `version` (v3 default in
  RouterOS 7); mismatches show up as both-master too.

## Related

- [dhcp.md](dhcp.md) (hand out the virtual gateway),
  [firewall.md](firewall.md) (allow protocol `vrrp` between peers),
  [interfaces.md](interfaces.md) (the underlying LAN interface).
