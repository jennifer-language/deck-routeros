# IPsec: site-to-site tunnels

File: `src/topics/ipsec.j`. Paths: `/ip/ipsec/peer`, `.../identity`,
`.../policy`, `.../active-peers` (`IPSEC_PEER_PATH`,
`IPSEC_IDENTITY_PATH`, `IPSEC_POLICY_PATH`, `IPSEC_ACTIVE_PATH`).

## Background

IPsec is the *standards-based* site-to-site VPN: when the far end is a
Cisco, a pfSense, a cloud VPN gateway, or a partner you don't control,
IPsec (IKEv2) is the lingua franca. Between two MikroTiks you own,
[WireGuard](wireguard.md) is simpler and usually the better answer -
this topic exists for the interop case.

RouterOS splits a tunnel across three objects - the **peer** (who to
negotiate with, IKEv2), the **identity** (how to authenticate - here a
pre-shared key), and the **policy** (which traffic to encrypt:
local subnet ↔ remote subnet, tunnel mode). Around them, two things
kill more IPsec setups than crypto ever does:

1. **NAT before IPsec**: masquerade rewrites the LAN's source address
   *before* the policy can match - traffic silently takes the plain
   internet path. The fix is an accept rule in srcnat *before*
   masquerade.
2. **Firewall input**: IKE (udp/500), NAT-T (udp/4500), and ESP must be
   accepted from the peer.

`setupIpsecTunnel` does all five pieces in one call; both ends run the
mirror of it.

## Structs

```jennifer
mt.IpsecPeer       { id, name, address, exchangeMode, disabled }
mt.IpsecPolicy     { id, peer, srcAddress, dstAddress, tunnel, active, disabled }
mt.IpsecActivePeer { remoteAddress, state, established, uptime, side }
```

## Functions

| Function | Purpose |
|---|---|
| `setupIpsecTunnel(c, name, peerAddress, psk, localSubnet, remoteSubnet)` → id | the whole tunnel (idempotent) |
| `teardownIpsecTunnel(c, name)` | remove all five pieces |
| `ipsecActive(c)` → active peers | is it up? check `established` |
| `ipsecPolicies(c)` → policies | per-policy `active` flag |
| `ipsecPeers(c)` → peers | the configuration view |

## Example: two offices

Site A (LAN 192.168.10.0/24, public 198.51.100.1) and site B
(LAN 192.168.20.0/24, public 203.0.113.99):

```jennifer
# --- site A ---
mt.setupIpsecTunnel($c, "tobranch", "203.0.113.99",
    "a long random shared secret", "192.168.10.0/24", "192.168.20.0/24");

# --- site B (its own client): mirrored, SAME psk, subnets swapped ---
# mt.setupIpsecTunnel($cb, "tomain", "198.51.100.1",
#     "a long random shared secret", "192.168.20.0/24", "192.168.10.0/24");
```

Verify:

```jennifer
def live as list of mt.IpsecActivePeer init mt.ipsecActive($c);
for (def a in $live) {
    io.printf("%s: %s (%s, up %s)\n", $a.remoteAddress, $a.state, $a.side, $a.uptime);
}
def pols as list of mt.IpsecPolicy init mt.ipsecPolicies($c);
for (def pol in $pols) {
    io.printf("policy %s -> %s active=%t\n", $pol.srcAddress, $pol.dstAddress, $pol.active);
}
```

`established` + policy `active == true` = traffic flows. From a LAN
host, ping something on the far LAN (the router's own `ping` uses its
WAN source - test end-to-end from a client, or ping the far *LAN
gateway address* with the generic talk and a src-address).

## Pitfalls

- **Policy-based means no interface**: unlike WireGuard/GRE there is
  nothing to route or bridge - the policy itself grabs matching
  traffic. Consequently: overlapping/identical subnets on both sides
  cannot work; renumber one side.
- The PSK is the entire authentication - make it long and random, and
  transport it out of band. Certificates instead of PSKs are possible
  via `/ip/ipsec/identity` with the generic verbs and the
  [certificates](certificates.md) topic.
- Both ends behind NAT: at least one side needs a reachable public
  address (or port forwarding of udp/500+4500 to it). NAT-T handles
  the rest.
- The NAT bypass rule must stay *above* masquerade - `setupIpsecTunnel`
  places it there, but later manual NAT reordering can break it; the
  symptom is "tunnel established, no traffic".
- Check `ipsecActive` first when debugging: no entry at all = IKE
  blocked (firewall/reachability); `state` stuck negotiating = PSK or
  proposal mismatch (both ends' logs tell which).

## Related

- [wireguard.md](wireguard.md) (the simpler MikroTik-to-MikroTik
  answer), [nat.md](nat.md) (the bypass explained),
  [firewall.md](firewall.md), [gre.md](gre.md) (GRE-over-IPsec for
  routed multicast/OSPF setups, via the coupled `ipsec-secret`).
