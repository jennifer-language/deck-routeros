# GRE tunnels

File: `src/topics/gre.j`. Path: `/interface/gre` (`GRE_PATH`).

## Background

GRE is the plain, standardized (RFC 2784) tunnel: a point-to-point
**layer-3** link carried over IP. Where EoIP stretches one LAN across
sites (bridged, broadcasts and all), GRE connects two *networks* that
stay separate - each end keeps its own subnet and DHCP, and traffic
between them is **routed** through the tunnel. That makes GRE the right
shape for most site-to-site links, and because it is a standard, the
far end can be a Cisco, a Linux box, or anything else that speaks GRE.

The recipe is always the same three steps per end:

1. create the tunnel (remote = the other router),
2. address the tunnel ends in a tiny shared network (a `/30` holds
   exactly two hosts),
3. route the far site's networks at the far tunnel address.

## Struct

```jennifer
mt.GreTunnel {
    id, name,
    remoteAddress, localAddress,   # localAddress "" = automatic
    mtu, keepalive,
    running, disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `addGreTunnel(c, name, remoteAddress)` → id | plain tunnel |
| `addSecureGreTunnel(c, name, remoteAddress, ipsecSecret)` → id | with coupled IPsec |
| `greTunnels(c)` → `list of GreTunnel` | all tunnels |
| `greTunnelByName(c, name)` → `GreTunnel` | one tunnel |
| `removeGreTunnel(c, name)` | delete (routes through it die) |
| `enableGreTunnel(c, name)` / `disableGreTunnel(c, name)` | up / down |

Validation: the remote must be an IP address, the name free, and a
second tunnel to the same remote is refused with the owning tunnel
named. The IPsec secret is write-only.

## Example: routed site-to-site

Site A (LAN 192.168.10.0/24, public 198.51.100.1) to site B
(LAN 192.168.20.0/24, public 203.0.113.99):

```jennifer
# --- site A ---
mt.addGreTunnel($c, "grebranch", "203.0.113.99");
mt.addIpAddress($c, "10.99.0.1/30", "grebranch");
mt.addRoute($c, "192.168.20.0/24", "10.99.0.2", "branch LAN via GRE");

# --- site B (its own client) ---
# mt.addGreTunnel($cb, "gremain", "198.51.100.1");
# mt.addIpAddress($cb, "10.99.0.2/30", "gremain");
# mt.addRoute($cb, "192.168.10.0/24", "10.99.0.1", "main LAN via GRE");
```

Verify end to end from site A's router:

```jennifer
if (mt.isReachable($c, "10.99.0.2")) {
    io.printf("tunnel is routing\n");
}
```

With coupled IPsec across an untrusted path:

```jennifer
mt.addSecureGreTunnel($c, "grebranch", "203.0.113.99", "a long random shared secret");
```

## Pitfalls

- **GRE is unencrypted** by default; on the open internet use the
  IPsec-coupled variant - or ask whether WireGuard
  ([wireguard.md](wireguard.md)) does not solve the whole problem more
  simply. GRE's remaining edge: standard multi-vendor interop, and it
  carries multicast (OSPF adjacencies work across it).
- **Don't route the tunnel's own endpoint through the tunnel.** The
  route to the remote's *public* address must stay on the physical
  uplink, or the tunnel chases its own tail and flaps.
- MTU shrinks (1476 typical, less with IPsec): the "ping works, big
  transfers hang" symptom means lowering MTU or clamping TCP MSS
  (generic `set`).
- The firewall's `forward` chain sees the tunneled traffic like any
  other - permit LAN↔LAN explicitly on a hardened box
  ([firewall.md](firewall.md)).
- Keepalive (default `10s,10`) is what turns a dead path into
  `running == false`; without it the tunnel always claims to be up.

## Related

- [eoip.md](eoip.md) (the bridged, layer-2 sibling),
  [wireguard.md](wireguard.md) (usually the better encrypted answer),
  [routing.md](routing.md) (the routes through the tunnel),
  [tools.md](tools.md) (ping across the tunnel).
