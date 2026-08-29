<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# RADIUS

File: `src/topics/radius.j`. Path: `/radius` (`RADIUS_PATH`).

## Background

RADIUS centralizes authentication: instead of local `/user` accounts,
`/ppp/secret` VPN logins, or hotspot users scattered on each router,
credentials live on one server (FreeRADIUS, Windows NPS, an appliance)
and every router checks against it. You bind a RADIUS server to the
*subsystems* that should use it - admin `login`, `ppp` (the VPN
servers), `hotspot`, `wireless`, and so on.

## Struct

```jennifer
mt.RadiusServer { id, address, services, timeout, disabled, comment }
```

## Functions

| Function | Purpose |
|---|---|
| `radiusServers(c)` → `list of RadiusServer` | configured servers |
| `addRadiusServer(c, address, secret, services, comment)` → id | bind a server (idempotent) |
| `removeRadiusServer(c, address)` | remove one |

`services` is a comma list from: `login`, `ppp`, `hotspot`, `wireless`,
`dhcp`, `ipsec`, `dot1x` (validated). The shared `secret` authenticates
the *router* to the server and is write-only.

## Examples

Admin logins and VPN users from Active Directory (NPS):

```jennifer
mt.addRadiusServer($c, "10.0.9.20", "a shared secret", "login,ppp", "AD/NPS");
# then tell the login/ppp subsystems to actually use RADIUS - that is a
# per-subsystem toggle (generic set on /user/aaa or /ppp/aaa)
```

Audit:

```jennifer
def servers as list of mt.RadiusServer init mt.radiusServers($c);
for (def s in $servers) { io.printf("radius %s for %s\n", $s.address, $s.services); }
```

## Pitfalls

- **Binding a server is not the whole story** - the subsystem must also
  be told to use RADIUS (`/user/aaa use-radius=yes`, `/ppp/aaa
  use-radius=yes`, the hotspot profile's `use-radius`). Those toggles
  stay with the generic verbs.
- **Keep a local admin.** If RADIUS becomes unreachable and you disabled
  local auth, you are locked out - leave a local `full` user and put
  RADIUS *ahead* of it, not instead of it.
- The shared secret crosses the wire in the RADIUS protocol's weak
  obfuscation - put the RADIUS server on a trusted segment, or use
  RadSec.
- IKEv2 EAP ([vpn.md](vpn.md)) is a common reason to add `ppp`/`ipsec`
  RADIUS.

## Related

- [users.md](users.md), [vpn.md](vpn.md), [hotspot.md](hotspot.md),
  [services.md](services.md).
