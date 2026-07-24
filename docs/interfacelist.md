<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# Interface lists

File: `src/topics/interfacelist.j`. Paths: `/interface/list`
(`INTERFACE_LIST_PATH`), `/interface/list/member`
(`INTERFACE_LIST_MEMBER_PATH`).

## Background

An interface list is a named group of interfaces — `WAN`, `LAN`,
`MGMT` — that firewall (and other) rules can match as a whole. This is
how the RouterOS v7 default config is built: rules say "drop from `WAN`"
rather than naming `ether1`, so when you add a second uplink or move a
port, you edit the *list*, not a pile of rules. The built-in lists
`all`, `none`, and `dynamic` always exist.

## Struct

```jennifer
mt.InterfaceList { id, name, dynamic, comment }
```

## Functions

| Function | Purpose |
|---|---|
| `interfaceLists(c)` → `list of InterfaceList` | all lists |
| `addInterfaceList(c, name, comment)` → id | create a list (idempotent) |
| `removeInterfaceList(c, name)` | delete it (memberships go too) |
| `interfaceListMembers(c, listName)` → `list of string` | member interface names |
| `addToInterfaceList(c, listName, interfaceName)` → id | add a member (creates the list if missing) |
| `removeFromInterfaceList(c, listName, interfaceName)` | remove a member |

Firewall matching lives in the firewall builder:
`withInInterfaceList(rule, listName)` and
`withOutInterfaceList(rule, listName)` — see [firewall.md](firewall.md).

## Example: the WAN/LAN pattern

```jennifer
mt.addToInterfaceList($c, "WAN", "ether1");            # the uplink(s)
mt.addToInterfaceList($c, "LAN", "brlan");             # everything internal

# one rule covers the whole WAN group and follows it as it changes
def drop as mt.FirewallRule init mt.firewallRule(mt.CHAIN_INPUT, mt.ACTION_DROP);
$drop = mt.withInInterfaceList($drop, "WAN");
$drop = mt.withComment($drop, "drop unsolicited from WAN");
mt.addFirewallRule($c, $drop);
```

Audit:

```jennifer
def lists as list of mt.InterfaceList init mt.interfaceLists($c);
for (def il in $lists) {
    def members as list of string init mt.interfaceListMembers($c, $il.name);
    io.printf("%s: %d members\n", $il.name, len($members));
}
```

## Pitfalls

- **A list is only useful once rules reference it** — grouping alone
  changes nothing; the payoff is the firewall matchers.
- Put a new uplink into `WAN` *before* it carries traffic, so the WAN
  rules protect it from the first packet.
- The `dynamic` built-in list holds interfaces added by other features
  (e.g. a running VPN) — don't hand-manage it.

## Related

- [firewall.md](firewall.md) (the matchers), [interfaces.md](interfaces.md),
  [raw.md](raw.md) (raw rules use interface lists too).
