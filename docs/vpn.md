<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# Remote-access VPN (L2TP, SSTP, OpenVPN, IKEv2)

Files: `src/topics/ppp.j` (the shared user database), `l2tp.j`,
`sstp.j`, `ovpn.j`, and the IKEv2 additions in `ipsec.j`.

## Background

The site-to-site VPNs ([wireguard](wireguard.md), [ipsec](ipsec.md),
[gre](gre.md), [eoip](eoip.md)) join *networks*. Remote-access VPNs let
*people* dial in — a laptop in a café, a phone on cellular. RouterOS has
several, and which to pick is mostly about the client:

| Server | Client story | Needs |
|---|---|---|
| **L2TP/IPsec** | built into Windows/macOS/iOS/Android — nothing to install | a pre-shared key |
| **SSTP** | TLS on 443, crosses hotel/captive firewalls | a TLS certificate |
| **OpenVPN** | a client for everything, but a config file to import | a TLS certificate |
| **IKEv2** | native modern clients ("IKEv2" in iOS/macOS/Win) | a certificate + EAP users |

For most "let staff reach the office" cases, **L2TP/IPsec** is the least
friction. All four (except WireGuard) share one thing:

### The shared user database (PPP secrets)

L2TP, SSTP, OpenVPN, and PPTP all authenticate against `/ppp/secret`.
So the workflow is always: **enable a server, then add users** — the
users work for whichever servers you turned on.

```jennifer
mt.addVpnUser($c, "alice", "her password", "any", "field laptop");
mt.vpnUsers($c);              # list them
mt.pppActive($c);            # who is connected right now (any VPN type)
mt.kickPppUser($c, "alice"); # disconnect a session
```

`service` pins a login to one server type (`"l2tp"`, `"sstp"`,
`"ovpn"`) or `"any"`.

## L2TP/IPsec — the easy one

```jennifer
mt.enableLtwotpServer($c, "a long random ipsec secret");   # opens the firewall too
mt.addVpnUser($c, "alice", "her password", "l2tp", "laptop");
```

Clients enter: server = the router's public address or DNS name (see
[cloud.md](cloud.md) for a name on a dynamic IP), the pre-shared key,
and their username/password. `disableLtwotpServer($c)` turns it off and
removes the firewall openings. Never enable L2TP without the IPsec
secret — plain L2TP is cleartext (the helper refuses an empty secret).

## SSTP and OpenVPN — TLS-based

Both need a certificate ([certificates.md](certificates.md)); a public
Let's Encrypt cert means clients connect without warnings.

```jennifer
mt.enableSstpServer($c, "router-le-cert", 443);   # looks like HTTPS
mt.enableOvpnServer($c, "router-le-cert", 1194);
mt.addVpnUser($c, "bob", "his password", "any", "remote worker");
```

SSTP shines where other VPNs are blocked (it *is* HTTPS to a firewall).
OpenVPN is the most portable but needs a client config profile
(exported from the router / hand-built) on each device.

## Dialing out (VPN clients)

The router can also be the one dialing in to someone else's server:

```jennifer
mt.addLtwotpClient($c, "l2tpto-hq", "vpn.example.org", "branch", "password");
mt.addSstpClient($c, "sstpto-hq", "vpn.example.org", "branch", "password");
mt.addOvpnClient($c, "ovpnto-hq", "vpn.example.org", "branch", "password");
```

Each appears as an interface you can route or bridge.

## IKEv2 road-warrior (native clients, no L2TP layer)

`setupIkevTwoServer` (ipsec topic) builds the mode-config (client address
pool + DNS), a passive IKEv2 peer, and an EAP identity bound to your
certificate:

```jennifer
mt.setupIkevTwoServer($c, "roadwarriors", "router-le-cert",
    "10.200.0.10-10.200.0.200", "1.1.1.1");
```

This is the most involved to finish end-to-end — the certificate trust
chain must be right on the client, and EAP users come from RADIUS
([radius.md](radius.md)) or a user manager. Verify against a real
device; between networks you control, WireGuard is far simpler.

## Pitfalls

- **One user database.** Disabling a user (`disableVpnUser`) or deleting
  it affects every server it could use.
- **Firewall.** The `enable*Server` helpers open the needed input ports
  (and remove them on disable). A hand-built firewall that drops input
  first still needs those accepts above the drop.
- **L2TP behind NAT** relies on NAT-T (udp/4500) — the helper opens it;
  the client's own NAT usually just works.
- **Push a route/DNS to clients** via the PPP profile
  (`pppProfiles(c)`, then the generic `set` on `PPP_PROFILE_PATH`) — the
  default profile gives an address but no split-tunnel routes.
- **Certificates need a correct clock** ([clock.md](clock.md)) or TLS
  VPNs fail before they start.

## Related

- [certificates.md](certificates.md), [radius.md](radius.md),
  [cloud.md](cloud.md), [ipsec.md](ipsec.md),
  [wireguard.md](wireguard.md) (the modern site-to-site / road-warrior
  alternative).
