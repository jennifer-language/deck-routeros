# PPPoE: dial-in WAN

File: `src/topics/ppp.j`. Path: `/interface/pppoe-client`
(`PPPOE_CLIENT_PATH`).

## Background

DSL and many fiber lines do not hand out an address via DHCP - the
router must *dial in* over PPPoE with a user name and password from the
ISP. The session shows up as its own virtual interface (the PPPoE
interface), which then carries the public address and the default
route. Everything downstream (masquerade, port forwards) refers to
**that interface**, not the physical port the line is plugged into.

(RouterOS's `/ppp` menu itself holds the *server-side* pieces - secrets
and profiles for when the router terminates PPPoE for others. Drive
those with the generic verbs if you need them.)

## Struct

```jennifer
mt.PppoeClient {
    id, name,           # the PPPoE interface name
    interfaceName,      # the physical port it dials over
    user,
    usePeerDns,         # bool: ISP's DNS adopted
    addDefaultRoute,    # bool: ISP's route installed
    running,            # bool: session is up
    disabled, comment
}
```

The password is deliberately **not** in the struct - it is written on
setup and never read back.

## Functions

| Function | Purpose |
|---|---|
| `setupPppoe(c, name, interfaceName, user, password)` → id | create the dial-in uplink (idempotent by name) |
| `pppoeStatus(c, name)` → `PppoeClient` | is the session up? |
| `setPppoeCredentials(c, name, user, password)` | change user/password (reconnects) |
| `pppoeClients(c)` → `list of PppoeClient` | all dial-in clients |
| `removePppoeClient(c, name)` | delete the uplink |
| `enablePppoeClient(c, name)` / `disablePppoeClient(c, name)` | dial / hang up |

## Examples

The complete DSL edge:

```jennifer
mt.setupPppoe($c, "pppoewan", "ether1", "user@provider.example", "secret");
mt.addMasquerade($c, "pppoewan", "lan to internet");   # note: the PPPoE name!

def dsl as mt.PppoeClient init mt.pppoeStatus($c, "pppoewan");
if ($dsl.running) {
    io.printf("dial-in is up as %s\n", $dsl.user);
} else {
    io.printf("dial-in is down - check credentials and line\n");
}
```

The ISP changed your password:

```jennifer
mt.setPppoeCredentials($c, "pppoewan", "user@provider.example", "newsecret");
```

Force a reconnect (hang up, dial again):

```jennifer
mt.disablePppoeClient($c, "pppoewan");
mt.enablePppoeClient($c, "pppoewan");
```

## Pitfalls

- **Masquerade the PPPoE interface** (`"pppoewan"`), not the ethernet
  port (`"ether1"`). The public address lives on the session.
- `running == false` with correct credentials usually means the modem
  is not in bridge mode, or the line carries the PPPoE service on a
  VLAN - many ISPs (e.g. VLAN 7) need
  `addVlan(c, "vlanisp", 7, "ether1")` first and the PPPoE client on
  `"vlanisp"` (see [vlans.md](vlans.md)).
- PPPoE reduces the MTU (typically 1492). RouterOS handles MSS clamping
  in its default firewall; on a hand-built firewall you may need a
  mangle rule (generic verbs, `/ip/firewall/mangle`).
- Setup defaults to adopting the ISP's default route and DNS; change
  those afterwards with the generic `set` on `PPPOE_CLIENT_PATH` if
  needed.

## Related

- [nat.md](nat.md), [dhcp.md](dhcp.md) (the DHCP flavor of WAN),
  [vlans.md](vlans.md) (ISPs that run PPPoE on a tag).
