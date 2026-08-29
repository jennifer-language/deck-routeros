<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# IPv6

File: `src/topics/ipv6.j`. Paths: `/ipv6/settings`
(`IPV6_SETTINGS_PATH`), `/ipv6/address` (`IPV6_ADDRESS_PATH`),
`/ipv6/nd` (`IPV6_ND_PATH`).

## Background

IPv6 on RouterOS is a second, independent stack. That independence is
the thing to hold on to: the `/ip/firewall` rules from
[firewall.md](firewall.md) do **not** filter IPv6, and NAT - the
accident that hides your LAN on v4 - is not in play, because every host
with a global v6 address is directly reachable from the internet.

So there are only two honest positions, and the module gives you both:

- **Run IPv6 properly** - address the LAN, advertise it, and write v6
  firewall rules. Reachability is a feature, not a leak, once something
  is filtering.
- **Turn it off** - `disableIpv6(c)`. Leaving it half-configured is the
  worst of the three, because hosts still autoconfigure from any router
  advertisement on the wire and reach the internet around rules that
  only ever matched v4.

A LAN prefix is a **/64**. Not a convention you may tighten: SLAAC -
how clients build their own address - is defined only for /64, so a /72
LAN silently leaves clients unaddressed. Your ISP delegates something
shorter (a /56 or /48) and you cut /64s out of it, one per LAN.

## Structs

```jennifer
mt.Ipv6Settings { disabled, forward, acceptRouterAdvertisements,
                  acceptRedirects, maxNeighborEntries }
mt.Ipv6Address  { id, address, interfaceName, advertise, eui64,
                  linkLocal, dynamic, disabled, comment }
mt.Ipv6Nd       { id, interfaceName, raInterval, raLifetime,
                  managed, otherConfig, advertiseDns, disabled }
```

## Functions

| Function | Purpose |
|---|---|
| `ipv6Settings(c)` → `Ipv6Settings` | the global stack settings |
| `disableIpv6(c)` / `enableIpv6(c)` | switch the whole stack off / on |
| `setIpv6Forwarding(c, enabled)` | route IPv6 between interfaces |
| `setIpv6AcceptRouterAdvertisements(c, enabled)` | configure the router itself from upstream RAs |
| `ipv6Addresses(c)` → `list of Ipv6Address` | every address, static and dynamic |
| `ipv6AddressesOn(c, interfaceName)` | the addresses on one interface |
| `addIpv6Address(c, cidr, interfaceName)` → id | a static address, advertised |
| `addIpv6AddressWith(c, cidr, interfaceName, advertise, eui64)` → id | full control |
| `removeIpv6Address(c, cidr)` | drop a static address |
| `ipv6Nd(c)` → `list of Ipv6Nd` | the neighbor-discovery entries |
| `advertiseIpv6On(c, interfaceName)` → id | announce this router on a LAN (idempotent) |
| `stopAdvertisingIpv6On(c, interfaceName)` → id | stop announcing |
| `setIpv6NdFlags(c, interfaceName, managed, otherConfig)` → id | the M and O flags |

## Example

Address a LAN and let clients configure themselves:

```jennifer
mt.enableIpv6($c);
mt.setIpv6Forwarding($c, true);
mt.addIpv6Address($c, "2001:db8:1::1/64", "brlan");
mt.advertiseIpv6On($c, "brlan");
mt.setIpv6NdFlags($c, "brlan", false, true);   # SLAAC, DNS from DHCPv6
```

Or close it down on a v4-only network:

```jennifer
mt.disableIpv6($c);
```

Audit what is actually configured - `dynamic` separates what RouterOS
built itself (link-local, SLAAC, a delegated prefix) from what you set:

```jennifer
for (def a in mt.ipv6Addresses($c)) {
    if (not $a.dynamic) { io.printf("static %s on %s\n", $a.address, $a.interfaceName); }
}
```

## Pitfalls

- **The v4 firewall does not filter v6.** A router with working IPv6 and
  no `/ipv6/firewall` rules exposes every LAN host directly. Write the v6
  rules, or run `disableIpv6`.
- **`enableIpv6` / `disableIpv6` want a reboot.** The setting sticks
  immediately; the running stack may not clear until the router restarts.
- **A LAN must be a /64** - SLAAC is defined for nothing else.
- **`advertise` is what makes clients configure themselves**, not the
  address. An address with `advertise: false` addresses the router and
  nothing else, which is right for a router-to-router link and wrong for
  a LAN.
- **Dynamic addresses cannot be removed** - `removeIpv6Address` says so
  rather than failing obscurely. Remove whatever creates them (the
  DHCPv6 client, the RA) instead.
- **`removeIpv6Address` matches the address as text**, the way its v4
  counterpart does - but IPv6 has several spellings for one address, so
  `2001:db8:1::1/64` will not match a row RouterOS stored as
  `2001:0db8:1::1/64`. Pass it back exactly as `ipv6Addresses(c)`
  reports it, or remove by id with the generic `remove(c, path, id)`.
- Passing a v4 CIDR to these calls is rejected with a message that says
  so; it is the likely slip.

## Related

- [ip.md](ip.md) (the v4 counterpart), [firewall.md](firewall.md) (and
  the separate v6 chains it does *not* cover), [dhcp.md](dhcp.md),
  [dns.md](dns.md), [routing.md](routing.md).
