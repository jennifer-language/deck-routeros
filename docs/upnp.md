<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# UPnP

File: `src/topics/upnp.j`. Paths: `/ip/upnp` (`UPNP_PATH`),
`/ip/upnp/interfaces` (`UPNP_INTERFACES_PATH`).

## Background

UPnP-IGD lets LAN devices — game consoles, some P2P apps, VoIP boxes —
ask the router to open their own port forwards, no manual NAT rule. It
is a convenience with a real security cost: *any* device on an
`internal` interface can punch a hole from the internet to itself. Fine
on a trusted home LAN, wrong on a guest or untrusted network. For UPnP
to work you must also tell the router which interface is the LAN
(`internal`) and which is the WAN (`external`).

## Structs

```jennifer
mt.UpnpSettings  { enabled }
mt.UpnpInterface { id, interfaceName, role, disabled }   # role: internal / external
```

## Functions

| Function | Purpose |
|---|---|
| `upnpStatus(c)` → `UpnpSettings` | on/off |
| `enableUpnp(c)` / `disableUpnp(c)` | switch the service |
| `upnpInterfaces(c)` → `list of UpnpInterface` | configured roles |
| `setUpnpInterface(c, interfaceName, role)` | mark `internal` or `external` (idempotent) |
| `removeUpnpInterface(c, interfaceName)` | clear a role |

## Example

```jennifer
mt.enableUpnp($c);
mt.setUpnpInterface($c, "ether1", "external");   # the WAN
mt.setUpnpInterface($c, "brlan", "internal");    # the trusted LAN
```

## Pitfalls

- **Security:** UPnP is a self-service hole puncher. On any network with
  devices you don't fully trust, leave it off and forward ports
  explicitly ([nat.md](nat.md)). Never mark a guest interface
  `internal`.
- **Both roles are required** — an `external` without an `internal` (or
  vice versa) does nothing.
- Forwards UPnP creates show up in `/ip/firewall/nat` (dynamic rules) —
  inspect them with [nat.md](nat.md)'s `natRules(c)` to see what your
  devices opened.

## Related

- [nat.md](nat.md) (the explicit, safer alternative and where UPnP's
  rules land), [services.md](services.md), [firewall.md](firewall.md).
