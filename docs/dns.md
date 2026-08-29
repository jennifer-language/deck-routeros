# DNS

File: `src/topics/dns.j`. Paths: `/ip/dns` (`DNS_PATH`),
`/ip/dns/static` (`DNS_STATIC_PATH`).

## Background

The router has a small DNS resolver of its own. Two independent jobs:

1. **Resolve for itself** - it needs upstream servers to check for
   updates, resolve NTP hosts, etc.
2. **Resolve for the LAN** - clients (usually told via DHCP) send their
   queries to the router, which caches and forwards them. That needs
   `allow-remote-requests` switched on.

On top of that, *static entries* let the router answer local names
(`nas.lan`) itself without any external DNS.

## Structs

```jennifer
mt.DnsSettings { servers, allowRemoteRequests, cacheSize, cacheUsed }
mt.DnsEntry    { id, name, address, ttl, disabled, comment }
```

## Functions

| Function | Purpose |
|---|---|
| `dnsSettings(c)` → `DnsSettings` | read the resolver state |
| `setDnsServers(c, servers)` | set upstreams, comma-separated |
| `allowRemoteDnsRequests(c, allow)` | answer (or refuse) client queries |
| `dnsStaticEntries(c)` → `list of DnsEntry` | local names |
| `addDnsEntry(c, name, address)` → id | add a local name |
| `removeDnsEntry(c, name)` | remove a local name |

Server lists are validated (every entry must parse as an IP address)
and normalized (`" 1.1.1.1 , 9.9.9.9 "` → `"1.1.1.1,9.9.9.9"`).

## Examples

Point the router at public resolvers and serve the LAN:

```jennifer
mt.setDnsServers($c, "1.1.1.1,9.9.9.9");
mt.allowRemoteDnsRequests($c, true);
```

Then tell DHCP clients to use the router (the `dns` parameter of
`setupDhcp` - the gateway address):

```jennifer
mt.setupDhcp($c, "dhcplan", "brlan", "192.168.88.0/24",
    "192.168.88.1", "192.168.88.10", "192.168.88.199",
    "192.168.88.1");                     # <- clients ask the router
```

Local names for LAN devices:

```jennifer
mt.addDnsEntry($c, "nas.lan", "192.168.88.50");
mt.addDnsEntry($c, "printer.lan", "192.168.88.51");
```

Check the cache:

```jennifer
def d as mt.DnsSettings init mt.dnsSettings($c);
io.printf("upstreams %s, cache %s of %s used\n",
    $d.servers, $d.cacheUsed, $d.cacheSize);
```

## The cache

Path: `/ip/dns/cache` (`DNS_CACHE_PATH`). Every answer the resolver
hands out is cached until its TTL runs out; inspecting the cache tells
you what the router would answer *right now* - the ground truth when a
client claims "DNS is broken":

```jennifer
# what does the router currently believe about a name?
def records as list of mt.DnsCacheEntry init mt.dnsCacheFor($c, "example.org");
for (def rec in $records) {
    io.printf("%s %s -> %s (ttl %s)\n", $rec.kind, $rec.name, $rec.data, $rec.ttl);
}

# just the addresses (A/AAAA, CNAMEs skipped)
def addrs as list of string init mt.resolvedAddresses($c, "example.org");

# after a DNS change upstream: drop everything learned
mt.flushDnsCache($c);
```

`dnsCache(c)` returns the whole cache (large on a busy router);
`DnsCacheEntry.isStatic` marks records that come from static entries -
flushing never touches those, they are configuration, not cache.
Matching is case-insensitive, as DNS names are.

## Ad and malware blocking (adlists, 7.15+)

RouterOS 7.15+ can apply hosts-format blocklists router-wide: the
resolver answers `0.0.0.0` for every name on the list, for every client
using the router as its DNS server.

```jennifer
mt.allowRemoteDnsRequests($c, true);   # clients must use the router as resolver
mt.addAdlist($c, "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts");

def adlists as list of mt.DnsAdlist init mt.dnsAdlists($c);
for (def a in $adlists) { io.printf("%s blocks %s names\n", $a.url, $a.matchCount); }
```

`addAdlist` is idempotent by URL; `removeAdlist(c, url)` removes one.
Large lists cost RAM (the router holds them in memory) - a small box
may not fit a million-entry list.

## Pitfalls

- **`allowRemoteDnsRequests(c, true)` answers on ALL interfaces,
  including the WAN.** On an internet-facing router you are then an
  open resolver - abused for amplification attacks - unless the
  firewall closes UDP and TCP port 53 on the WAN side:

  ```jennifer
  def r as mt.FirewallRule init mt.firewallRule(mt.CHAIN_INPUT, mt.ACTION_DROP);
  $r = mt.withProtocol($r, "udp");
  $r = mt.withDstPort($r, "53");
  $r = mt.withInInterface($r, "ether1");     # the WAN port
  $r = mt.withComment($r, "no dns from wan");
  mt.addFirewallRule($c, $r);
  # repeat with "tcp"
  ```

- Static entries only help clients that actually *use* the router as
  their DNS server.
- A WAN configured with `setupWan` defaults (`use-peer-dns`) overwrites
  your `setDnsServers` choice with the ISP's on every lease - use
  `setupWanWith(c, iface, false, true)` to keep yours.
- After `setDnsServers`, old answers from the previous upstreams live
  on until their TTL expires - `flushDnsCache` makes the change take
  effect immediately.
- An empty `dnsCacheFor` result is not an error: it just means nobody
  asked the router for that name recently.

## Related

- [dhcp.md](dhcp.md), [firewall.md](firewall.md).
