# Static routes

File: `src/topics/routing.j`. Path: `/ip/route` (`ROUTE_PATH`).
Constant: `DEFAULT_ROUTE` (`"0.0.0.0/0"`).

## Background

A route says: "traffic for network X goes to next hop Y". The routing
table is consulted most-specific-first; the *default route*
(`0.0.0.0/0`) matches everything without a better match - it is "the
internet is that way".

Routes come from three sources: *connected* (created automatically for
every interface address), *dynamic* (routing protocols, DHCP, PPPoE),
and *static* - the ones you place by hand, which is what this topic
manages. Note the naming: static routes live under `/ip/route`;
RouterOS's `/routing` menu holds the dynamic protocols (OSPF, BGP).

When several routes cover the same destination, the *distance* decides
(lower wins) - which makes a higher-distance twin a standby that takes
over when the preferred route's gateway dies.

## Struct

```jennifer
mt.Route {
    id, dstAddress, gateway,
    distance,          # string as reported; RouterOS default "1"
    routingTable,      # "main" normally
    active,            # currently used
    dynamic,           # created by a protocol/service - not removable
    disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `routes(c)` → `list of Route` | the whole table (filter on `.dynamic`) |
| `addRoute(c, dstAddress, gateway, comment)` → id | plain static route |
| `addDefaultRoute(c, gateway, comment)` → id | the `0.0.0.0/0` shorthand |
| `addRouteWithDistance(c, dstAddress, gateway, distance, comment)` → id | backup routes |
| `removeRoute(c, dstAddress)` | remove the first *static* route to a destination |
| `enableRoute(c, dstAddress)` / `disableRoute(c, dstAddress)` | switch on / off |

The gateway may be an **IP address or an interface name**; if it is not
an IP, routeros verifies the interface exists - so both a mistyped
address and a mistyped interface fail loudly.

## Examples

Reach a branch office behind another router on the LAN:

```jennifer
mt.addRoute($c, "10.20.0.0/16", "192.168.88.254", "to branch office");
```

Primary and backup uplink (failover by distance):

```jennifer
mt.addDefaultRoute($c, "203.0.113.1", "primary isp");
mt.addRouteWithDistance($c, "0.0.0.0/0", "198.51.100.1", 10, "backup isp");
```

While the primary gateway answers, the distance-1 route wins; when it
becomes unreachable the distance-10 route takes over.

Inspect the table without the noise of dynamic routes:

```jennifer
def rts as list of mt.Route init mt.routes($c);
for (def rt in $rts) {
    if (not $rt.dynamic) {
        io.printf("%s via %s distance %s active=%t\n",
            $rt.dstAddress, $rt.gateway, $rt.distance, $rt.active);
    }
}
```

## Policy routing rules

Paths: `/routing/rule` (`ROUTING_RULE_PATH`), `/routing/table`
(`ROUTING_TABLE_PATH`) - RouterOS v7 (v6 kept rules under
`/ip/route/rule`; generic verbs there).

Distance-based failover switches uplinks for *everyone*; policy routing
decides *per source*: "the guest subnet uses the backup line, always".
A rule is checked before the main table and sends matching traffic to
another routing table - no per-packet marking involved, which makes
rules the simpler and cheaper alternative to the mangle topic's
`markRoutingFor` whenever a source match is enough (marks remain for
matches that need full firewall power: ports, protocols, address
lists).

```jennifer
# guests use the backup ISP, everything else stays on main
mt.useRoutingTable($c, "10.30.0.0/24", "backupisp", "guests via backup");
# the table is created if missing - it still needs its default route:
mt.add($c, mt.ROUTE_PATH, {"dst-address": "0.0.0.0/0",
    "gateway": "198.51.100.1", "routing-table": "backupisp"});
```

`useRoutingTable` uses action `lookup`: destinations the table cannot
answer fall back to the main table (graceful).
`useRoutingTableOnly` is the strict variant - "backup uplink or
nothing". `routingRules(c)` lists them in evaluation order;
`removeRoutingRule(c, srcAddress, table)` undoes one. All adds are
idempotent by source + table.

## Pitfalls

- **The gateway must be directly reachable** (inside a connected
  network). A route via an address the router cannot reach shows
  `active == false` and does nothing.
- `removeRoute` / `enableRoute` / `disableRoute` match the destination
  string *exactly as listed* and only consider static routes; with
  several static routes to the same destination (failover pairs) the
  first listed is affected - use ids from `routes(c)` with the generic
  verbs for surgical work.
- A WAN configured via [dhcp.md](dhcp.md) or [ppp.md](ppp.md) installs
  its own *dynamic* default route. Adding a static one on top creates
  competition - either let the WAN own it, or disable
  `addDefaultRoute` in `setupWanWith` and manage it here.
- Distance-based failover reacts to the gateway becoming *unreachable*
  (ARP), not to "the internet behind it is broken". Recursive
  gateway checks exist in RouterOS (`check-gateway`, scope tricks) via
  the generic verbs.
- A policy-routed table without a default route makes its sources'
  internet unreachable (`useRoutingTableOnly`) or silently fall back
  to main (`useRoutingTable`) - either way, give the table its route.
- Replies to inbound connections follow the rules too: with two
  uplinks, connections arriving on the backup line need their replies
  routed back out the same way (a rule per uplink source, or
  connection marks via [mangle.md](mangle.md)).

## Related

- [ip.md](ip.md) (connected routes), [dhcp.md](dhcp.md) /
  [ppp.md](ppp.md) (dynamic default routes),
  [wireguard.md](wireguard.md) (allowed-address creates routes too).
