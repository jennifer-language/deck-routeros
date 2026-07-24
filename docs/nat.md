# NAT: masquerade and port forwarding

File: `src/topics/nat.j`. Path: `/ip/firewall/nat` (`NAT_PATH`).

## Background

NAT rewrites addresses as packets pass the router. Two chains:

- `CHAIN_SRCNAT` (`"srcnat"`) rewrites the **source** of outgoing
  traffic. The everyday case is `ACTION_MASQUERADE`: the whole LAN
  appears as the router's own public address - without it, a private
  LAN cannot reach the internet.
- `CHAIN_DSTNAT` (`"dstnat"`) rewrites the **destination** of incoming
  traffic. The everyday case is `ACTION_DST_NAT`: a port forward that
  publishes an inside service.

## Functions

| Function | Purpose |
|---|---|
| `addMasquerade(c, outInterface, comment)` → id | LAN → internet via the router's address |
| `forwardPort(c, protocol, publicPort, toAddress, toPort, comment)` → id | publish an inside service |
| `forwardPortOn(c, inInterface, protocol, publicPort, toAddress, toPort, comment)` → id | same, pinned to the WAN interface (prefer this) |
| `natRules(c)` → `list of NatRule` | read everything back |
| `removeNatRule(c, id)` | delete by id |
| `removeNatRuleByComment(c, comment)` | delete by comment |
| `enableNatRuleByComment(c, comment)` | re-open |
| `disableNatRuleByComment(c, comment)` | temporarily close (rule kept) |

`addMasquerade` is **idempotent**: if a masquerade rule for that
interface already exists, its id is returned and nothing is duplicated
- stacked masquerade rules are a classic RouterOS mess.

## Examples

The standard internet edge (with a DHCP WAN, see
[dhcp.md](dhcp.md)):

```jennifer
mt.setupWan($c, "ether1");
mt.addMasquerade($c, "ether1", "lan to internet");
```

Publish an internal web server on port 8080:

```jennifer
mt.forwardPortOn($c, "ether1", "tcp", 8080, "192.168.88.10", 80, "web server");
```

Temporarily close the forward without losing it, e.g. during
maintenance:

```jennifer
mt.disableNatRuleByComment($c, "web server");
# ... later ...
mt.enableNatRuleByComment($c, "web server");
```

Audit:

```jennifer
def nats as list of mt.NatRule init mt.natRules($c);
for (def n in $nats) {
    io.printf("%s/%s dst-port %s -> %s:%s %s\n",
        $n.chain, $n.action, $n.dstPort, $n.toAddresses, $n.toPorts, $n.comment);
}
```

## Pitfalls

- **A port forward is not enough on its own** - the firewall's
  `forward` chain must also accept the redirected traffic. On a default
  RouterOS config that usually works (established/related + dstnat'ed
  accepted); on a hardened one, add an accept rule (see
  [firewall.md](firewall.md)).
- **Prefer `forwardPortOn`.** Without an in-interface match the
  redirect applies to *any* incoming traffic to that port - including
  LAN clients talking to the router - which produces confusing
  behavior.
- Port forwarding needs `tcp` or `udp` (routeros enforces this;
  icmp has no ports).
- Reaching a forwarded service from *inside* the LAN via the public
  address needs hairpin NAT (an extra srcnat rule) - out of scope for
  the shortcut; use the generic `add` on `NAT_PATH`.
- Masquerade breaks long-lived connections when the WAN address
  changes; that is inherent to masquerade, not to routeros.

## Related

- [firewall.md](firewall.md), [dhcp.md](dhcp.md) (WAN),
  [ppp.md](ppp.md) (masquerade the PPPoE interface for DSL uplinks).
