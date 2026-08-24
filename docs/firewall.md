# Firewall (filter rules)

File: `src/topics/firewall.j`. Path: `/ip/firewall/filter`
(`FIREWALL_PATH`).

## Background

Filter rules decide which packets live and which die. Every rule sits
in a *chain* - which traffic it looks at:

- `CHAIN_INPUT` (`"input"`): traffic **to the router itself** (its SSH,
  its DNS, its WinBox).
- `CHAIN_FORWARD` (`"forward"`): traffic **through** the router
  (LAN to internet, LAN to LAN).
- `CHAIN_OUTPUT` (`"output"`): traffic the router itself originates.

Rules are evaluated top to bottom; the first match wins. The *action*
says what happens: `ACTION_ACCEPT`, `ACTION_DROP` (silent),
`ACTION_REJECT` (tells the sender).

## The rule builder

A `FirewallRule` is built value-semantically: start with chain+action,
refine with `with*` helpers (each returns a fresh copy), then create it
on the router:

```jennifer
def r as mt.FirewallRule init mt.firewallRule(mt.CHAIN_FORWARD, mt.ACTION_DROP);
$r = mt.withProtocol($r, "tcp");
$r = mt.withSrcAddress($r, "10.0.0.0/8");
$r = mt.withDstPort($r, "445");
$r = mt.withComment($r, "no smb forwarding");
def id as string init mt.addFirewallRule($c, $r);
```

Refiners: `withProtocol`, `withSrcAddress`, `withDstAddress`,
`withSrcAddressList`, `withDstAddressList` (match a whole named set -
see [addresslist.md](addresslist.md)), `withSrcPort`, `withDstPort`
(single "80", list "80,443", range "8000-8100"), `withInInterface`,
`withOutInterface`, `withComment`, `withDisabled`. Unset fields are simply omitted from the rule - an
empty builder matches everything in its chain.

Validation happens before the wire: unknown actions and protocols are
rejected with the allowed values listed, and a port match without a
protocol fails with "call withProtocol(rule, \"tcp\") ... first"
(RouterOS's own error for that is much less helpful).

## Comments as handles

Give every rule a distinct comment - it is the friendly handle for
management without ids:

```jennifer
mt.disableFirewallRuleByComment($c, "no smb forwarding");  # pause it
mt.enableFirewallRuleByComment($c, "no smb forwarding");   # resume
mt.removeFirewallRuleByComment($c, "no smb forwarding");   # delete
```

## Ordering

The chains are walked top to bottom and stop at the first match, so
position *is* the policy. `addFirewallRule` appends, which means a rule
added after a broad drop sits below it and never fires. Lift it back:

```jennifer
def wg as string init mt.allowService($c, "udp", 13231, "wireguard in");
mt.moveFirewallRule($c, $wg, $dropNonLanId);       # by id
```

Addressed by the comment handles instead, which survive a rule being
re-added:

```jennifer
mt.moveFirewallRuleByComment($c, "wireguard in", "drop everything else");
```

Pass `""` as the destination to send a rule to the bottom, and reach for
the generic verbs from [core.md](core.md) for the ends of any ordered
list:

```jennifer
mt.moveFirewallRuleByComment($c, "log leftovers", "");   # to the bottom
mt.moveRuleToTop($c, mt.FIREWALL_PATH, $establishedId);  # the cheap match first
```

The same pair exists for the other ordered tables - `moveNatRule` /
`moveNatRuleByComment` ([nat.md](nat.md)), `moveMangleRule` /
`moveMangleRuleByComment` ([mangle.md](mangle.md)), and `moveRawRule` /
`moveRawRuleByComment` ([raw.md](raw.md)).

## Shortcuts

```jennifer
# accept a service to the router (input chain)
mt.allowService($c, "tcp", 22, "ssh management");

# drop everything a source sends to the router (input chain)
mt.blockAddress($c, "203.0.113.7", "known scanner");
```

## Reading back

```jennifer
def rules as list of mt.FirewallRule init mt.firewallRules($c);
for (def fr in $rules) {
    io.printf("%s %s %s -> %s %s\n",
        $fr.chain, $fr.action, $fr.srcAddress, $fr.dstAddress, $fr.comment);
}
```

`removeFirewallRule(c, id)` deletes by id when you have one.

## Pitfalls

- **Order matters and routeros appends.** A new rule lands at the end
  of its chain. If an earlier rule already dropped the traffic, your
  new accept never fires - fix it with `moveFirewallRule` /
  `moveFirewallRuleByComment` (see [Ordering](#ordering)), not by
  deleting and re-adding.
- **Do not lock yourself out.** Adding a drop rule on `input` that
  matches your own management connection disconnects you. Add your
  accept rules (e.g. `allowService`) *before* broad drops.
- A port match (`withDstPort`) needs a protocol; icmp has no ports.
- `drop` is silent (the sender waits for a timeout); `reject` answers.
  For internet-facing rules, `drop` reveals less.
- Custom chains are allowed (`firewallRule("mychain", ...)` +
  `jump` action) but managing the jump targets is up to you.

## Related

- [nat.md](nat.md) - a port forward also needs the forward chain to
  let the redirected traffic through.
- [dns.md](dns.md) - close UDP/TCP 53 on the WAN when the router
  resolves for its clients.
