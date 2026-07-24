# Firewall address lists

File: `src/topics/addresslist.j`. Path:
`/ip/firewall/address-list` (`ADDRESS_LIST_PATH`).

## Background

An address list is a named set of addresses the firewall can reference
as a whole. That inverts the usual maintenance burden: instead of one
firewall rule per blocked host, you keep **one rule** ("drop everything
on `blocklist`") and manage only the *list* - adding and removing
members never touches the firewall again.

Entries can be single IPs, CIDR networks, or DNS names (RouterOS
resolves the name and tracks address changes). Entries may also carry a
**timeout** and disappear by themselves - ideal for penalties. Some
entries are *dynamic*: firewall rules with `add-src-to-address-list`
create them on the fly (that action is available through the generic
verbs).

## Struct

```jennifer
mt.AddressListEntry {
    id, listName, address,
    timeout,          # "" = permanent
    dynamic,          # created by a rule/timeout mechanism
    disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `addressLists(c)` → `list of string` | distinct list names |
| `addressListEntries(c, listName)` → `list of AddressListEntry` | one list's members |
| `addToAddressList(c, listName, address, comment)` → id | add permanently (idempotent) |
| `addToAddressListTimed(c, listName, address, timeout, comment)` → id | add with expiry |
| `removeFromAddressList(c, listName, address)` | take one member off |
| `clearAddressList(c, listName)` | remove all static members |
| `dropAddressList(c, listName, chain, comment)` → id | one drop rule covering the whole list |

Rule-side matchers live in the firewall builder:
`withSrcAddressList(rule, listName)` and
`withDstAddressList(rule, listName)` (see [firewall.md](firewall.md)).

## Examples

The pattern - one rule, living list:

```jennifer
# once: the rule
mt.dropAddressList($c, "blocklist", mt.CHAIN_INPUT, "drop blocklisted");

# forever after: only list maintenance
mt.addToAddressList($c, "blocklist", "203.0.113.7", "ssh scanner");
mt.addToAddressList($c, "blocklist", "198.51.100.0/24", "botnet range");
mt.removeFromAddressList($c, "blocklist", "203.0.113.7");
```

A 24-hour penalty that cleans itself up:

```jennifer
mt.addToAddressListTimed($c, "blocklist", "192.0.2.66", "1d", "brute force");
```

Allow-listing with the builder - only the admin net reaches WinBox:

```jennifer
mt.addToAddressList($c, "admins", "10.0.9.0/24", "management net");

def r as mt.FirewallRule init mt.firewallRule(mt.CHAIN_INPUT, mt.ACTION_DROP);
$r = mt.withProtocol($r, "tcp");
$r = mt.withDstPort($r, "8291");
$r = mt.withComment($r, "winbox only for admins");
# drop everyone NOT on the list is a RouterOS negation - keep it simple
# and instead accept the list first, then drop the port:
def ok as mt.FirewallRule init mt.firewallRule(mt.CHAIN_INPUT, mt.ACTION_ACCEPT);
$ok = mt.withProtocol($ok, "tcp");
$ok = mt.withDstPort($ok, "8291");
$ok = mt.withSrcAddressList($ok, "admins");
$ok = mt.withComment($ok, "winbox for admins");
mt.addFirewallRule($c, $ok);   # accept first...
mt.addFirewallRule($c, $r);    # ...then the drop (order matters!)
```

Audit:

```jennifer
def names as list of string init mt.addressLists($c);
for (def n in $names) {
    def entries as list of mt.AddressListEntry init mt.addressListEntries($c, $n);
    io.printf("list %s: %d entries\n", $n, len($entries));
}
```

## Pitfalls

- **The list alone does nothing.** Without a rule referencing it
  (`dropAddressList` or the `with*AddressList` matchers), members are
  just bookkeeping.
- Rule order still matters: an accept-from-list must come *before* the
  broad drop it punches through (routeros appends - see
  [firewall.md](firewall.md)).
- `clearAddressList` leaves dynamic entries alone on purpose; they
  belong to whatever created them (timeouts, `add-src-to-address-list`
  rules).
- DNS-name entries depend on the router's resolver
  ([dns.md](dns.md)) and update at the name's TTL pace - fine for
  convenience, not for hard security boundaries.
- `addToAddressList` is idempotent, so re-running a provisioning
  script is safe; RouterOS itself would trap on the duplicate.

## Related

- [firewall.md](firewall.md), [dns.md](dns.md),
  [nat.md](nat.md).
