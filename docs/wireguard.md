# WireGuard VPN tunnels

File: `src/topics/wireguard.j`. Paths: `/interface/wireguard`
(`WIREGUARD_PATH`), `/interface/wireguard/peers`
(`WIREGUARD_PEER_PATH`). Needs **RouterOS v7** - the read functions
return empty lists on v6.

## Background

WireGuard is the modern, minimal VPN: each side has a keypair, you
exchange *public* keys, and a tunnel comes up when the first packets
flow. In RouterOS the local end is a WireGuard **interface** (with the
keypair and a UDP listen port) and every remote party is a **peer** on
that interface.

Key concepts the abstraction encodes:

- The **private key never leaves the router** - it is generated on the
  device, and routeros neither sets nor reads it. You only ever handle
  public keys (44 base64 characters ending `=`, validated locally).
- **allowed-address** is both a filter and a route: traffic from a peer
  is only accepted for these addresses, and traffic *to* them is routed
  into the tunnel. A single device is `/32` - the most common mistake
  is writing a bare IP, so routeros rejects it with exactly that hint.
- **last-handshake** is the liveness signal: a live tunnel handshakes
  roughly every 2 minutes.

## Structs

```jennifer
mt.WireguardInterface {
    id, name, publicKey, listenPort,     # listenPort is an int
    mtu, running, disabled, comment
}
mt.WireguardPeer {
    id, interfaceName, publicKey,
    endpointAddress, endpointPort,       # "" when the peer dials in
    allowedAddress, keepalive,
    lastHandshake, rx, tx,               # liveness + traffic counters
    disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `setupWireguardServer(c, name, listenPort, address)` → id | interface + VPN address + firewall hole, idempotent |
| `addWireguard(c, name, listenPort)` → id | just the interface (idempotent) |
| `wireguardPublicKey(c, name)` → string | the key to hand to the other side |
| `addWireguardPeer(c, iface, publicKey, allowedAddress, comment)` → id | let a device in (server side) |
| `connectWireguard(c, iface, publicKey, endpointHost, endpointPort, allowedAddress, comment)` → id | dial out to a server (client side, keepalive 25s) |
| `wireguardInterfaces(c)` / `wireguardPeers(c)` | state, counters, handshakes |
| `removeWireguardPeerByComment(c, comment)` | drop one peer |
| `removeWireguard(c, name)` | interface + its address + its firewall rule |
| `enableWireguard(c, name)` / `disableWireguard(c, name)` | all tunnels up / down |

## Example: road-warrior server

Let a laptop reach home from anywhere:

```jennifer
# 1. server: interface, VPN address, firewall opening - one call
mt.setupWireguardServer($c, "wgvpn", 13231, "10.100.0.1/24");

# 2. read the router's public key; put it into the laptop's WireGuard config
io.printf("server public key: %s\n", mt.wireguardPublicKey($c, "wgvpn"));

# 3. let the laptop in (its public key comes from its WireGuard app)
mt.addWireguardPeer($c, "wgvpn",
    "hIe5R2FTPjvrIrVXfy41chvUJ4CyOTdBEI3pQGea0R0=",
    "10.100.0.2/32", "laptop");
```

The laptop's config then uses: server address = your public IP/DNS,
port 13231, its own address 10.100.0.2/32, and allowed-ips of at least
10.100.0.0/24 (or 192.168.88.0/24 too, to reach the LAN - then also add
that network to the peer's allowed IPs *on the laptop side* and let the
firewall's forward chain permit VPN→LAN).

## Example: site-to-site (this router dials out)

```jennifer
mt.addWireguard($c, "wghome", 13231);
io.printf("our key (for the far end): %s\n", mt.wireguardPublicKey($c, "wghome"));
mt.connectWireguard($c, "wghome",
    "<the far end's public key>", "vpn.example.org", 13231,
    "10.100.0.0/24,192.168.10.0/24",     # what lives behind the far end
    "to headquarters");
mt.addIpAddress($c, "10.100.0.3/24", "wghome");
```

## Monitoring

```jennifer
def peers as list of mt.WireguardPeer init mt.wireguardPeers($c);
for (def p in $peers) {
    io.printf("peer %s: handshake %s, rx %s tx %s\n",
        $p.comment, $p.lastHandshake, $p.rx, $p.tx);
}
```

An empty `lastHandshake` (or one growing beyond ~2-3 minutes) means the
tunnel is down: wrong key, wrong endpoint, or UDP blocked.

## Pitfalls

- **allowed-address needs the prefix** - `10.100.0.2` is rejected; a
  single device is `10.100.0.2/32`. Overlapping allowed-addresses
  between peers on one interface do not work (last one wins).
- The firewall must accept UDP on the listen port (input chain).
  `setupWireguardServer` opens it for you (rule comment
  `"wireguard: <name>"`); `addWireguard` alone does not.
- WireGuard is silent by design: a wrong key produces no error
  anywhere, just no handshake. Check `wireguardPeers` first.
- Behind NAT, only the *dialing* side needs keepalive;
  `connectWireguard` sets 25 s automatically.
- Traffic between VPN and LAN passes the `forward` chain - permit it
  (see [firewall.md](firewall.md)) if peers should reach LAN devices.

## Related

- [firewall.md](firewall.md), [ip.md](ip.md),
  [routing.md](routing.md) (allowed-address installs routes).
