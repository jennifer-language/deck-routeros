# EoIP tunnels

File: `src/topics/eoip.j`. Path: `/interface/eoip` (`EOIP_PATH`).

## Background

EoIP is MikroTik's "very long ethernet cable": it carries raw ethernet
frames inside IP packets between two MikroTik routers. Bridge the
tunnel interface into the LAN on both ends, and the two sites share
*one* layer-2 network - same broadcast domain, same subnet, devices see
each other as if plugged into the same switch. That is something a
routed VPN (like WireGuard alone) deliberately does not do.

Three facts define every EoIP setup:

1. **It takes two.** Each router creates a tunnel pointing its
   `remote-address` at the other, and both must use the **same tunnel
   id** (0-65535). Mismatched ids fail silently - the tunnels just
   never come up.
2. **EoIP is not encrypted.** On a trusted path (a leased line, inside
   a WireGuard tunnel) that is fine; across the open internet it is
   not. Either set the coupled IPsec secret (`addSecureEoipTunnel`) or
   run EoIP over WireGuard - remote = the peer's VPN address.
3. **Layer 2 means everything crosses**: broadcasts, DHCP, mDNS. That
   is the point - and the caveat (one DHCP server for both sites, or
   careful separation).

## Struct

```jennifer
mt.EoipTunnel {
    id, name,
    remoteAddress, localAddress,   # localAddress "" = automatic
    tunnelId,                      # int, both ends must match
    mac, mtu, keepalive,
    running, disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `addEoipTunnel(c, name, remoteAddress, tunnelId)` → id | plain tunnel |
| `addSecureEoipTunnel(c, name, remoteAddress, tunnelId, ipsecSecret)` → id | with coupled IPsec |
| `eoipTunnels(c)` → `list of EoipTunnel` | all tunnels |
| `eoipTunnelByName(c, name)` → `EoipTunnel` | one tunnel |
| `removeEoipTunnel(c, name)` | delete (detach bridge ports first) |
| `enableEoipTunnel(c, name)` / `disableEoipTunnel(c, name)` | up / down |

Validation: the remote must be an IP address, the tunnel id 0-65535, a
name may not be taken, and a same-remote/same-id tunnel is refused with
the owning tunnel named. The IPsec secret is write-only.

## Example: one LAN across two sites, over WireGuard

The recommended stack - WireGuard provides the encrypted path, EoIP
provides layer 2 on top:

```jennifer
# assumption: a WireGuard tunnel already connects the sites
# (site A = 10.100.0.1, site B = 10.100.0.2; see wireguard.md)

# --- site A ---
mt.addEoipTunnel($c, "eoipbranch", "10.100.0.2", 7);
mt.addBridgePort($c, "brlan", "eoipbranch");

# --- site B (its own client) ---
# mt.addEoipTunnel($cb, "eoipmain", "10.100.0.1", 7);
# mt.addBridgePort($cb, "brlan", "eoipmain");
```

After both ends are up, a device at site B gets its DHCP lease from
site A's server - one LAN.

## Example: direct with coupled IPsec

When there is no WireGuard and the routers reach each other by public
address:

```jennifer
mt.addSecureEoipTunnel($c, "eoipbranch", "203.0.113.99", 7,
    "a long random shared secret");
# the far end mirrors it with the SAME secret and id
```

## Monitoring

```jennifer
def tunnels as list of mt.EoipTunnel init mt.eoipTunnels($c);
for (def t in $tunnels) {
    io.printf("eoip %s -> %s (id %d) running=%t\n",
        $t.name, $t.remoteAddress, $t.tunnelId, $t.running);
}
```

`running == false` on both ends usually means the path is down or the
tunnel ids differ; on one end only, check that the remote addresses
mirror each other.

## Pitfalls

- **MTU shrinks.** EoIP adds encapsulation overhead (more with IPsec),
  so full-size 1500-byte LAN frames may not fit the path. Symptoms are
  the classic "ping works, downloads hang" - lower the tunnel MTU
  (generic `set`) or enable `clamp-tcp-mss`.
- **Bridging both ends of two parallel tunnels builds a loop.** One
  EoIP per site pair into the same bridge, or run (R)STP on the
  bridges.
- Keepalive defaults to `10s,10`: the tunnel reports `running=false`
  when the far end stops answering - that is your health signal.
- EoIP is MikroTik-proprietary: the other end must be a MikroTik (or
  something implementing the same GRE dialect).
- The stretched LAN shares *everything*, including broadcast storms
  and rogue DHCP servers. For routed site-to-site connectivity without
  those risks, plain WireGuard (see [wireguard.md](wireguard.md)) is
  the simpler answer.

## Related

- [wireguard.md](wireguard.md) (the encrypted path underneath),
  [bridges.md](bridges.md) (where the tunnel ends up),
  [dhcp.md](dhcp.md) (one server serving both sites).
