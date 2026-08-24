# Core: connecting and the generic verbs

File: `src/topics/core.j`. Everything else in routeros builds on this
layer: the connection, the generic CRUD verbs that work on *any*
RouterOS list path, and the shared validation and row helpers.

## Background

The RouterOS API is organized like the console menu tree: list paths
such as `/interface/bridge` hold items, and every item is a map of
properties (`name`, `disabled`, ...) plus an internal id (`.id`,
looking like `"*3"`). Four verbs cover almost everything: `print`
(read), `add`, `set` (change), `remove`. routeros exposes exactly
those, typed and validated.

## Connecting

```jennifer
import "./routeros.j" as mt;

# plaintext API, port 8728
def c as mt.Client init mt.connect("192.168.88.1", "admin", "secret");

# TLS (api-ssl), port 8729
def cs as mt.Client init mt.connectTLS("192.168.88.1", "admin", "secret");

# custom port and explicit TLS choice
def cc as mt.Client init mt.connectWith("192.168.88.1", 18728, "admin", "secret", false);

mt.disconnect($c);
```

The `Client` struct wraps the underlying `mikrotik.Session`; you pass it
as the first argument to every routeros call and never touch the wire
protocol. The API service must be enabled on the router
(`/ip/service`, `api` or `api-ssl`); login works on RouterOS 6.43+ and
v7, with an automatic MD5 fallback for older routers.

## Generic verbs

These work on any list path, including ones routeros has no typed
helper for (`/ip/dhcp-server/option`, `/ppp/secret`, `/certificate`, ...):

| Function | Purpose |
|---|---|
| `getAll(c, path)` | all items as `list of map of string to string` |
| `add(c, path, attrs)` → id | create an item |
| `set(c, path, id, attrs)` | change properties (RouterOS's update) |
| `update(c, path, id, attrs)` | synonym of `set` |
| `remove(c, path, id)` | delete (RouterOS's delete) |
| `removeByName(c, path, name)` | delete by `name` property |
| `findByName(c, path, name)` | first item whose `name` matches (empty map on miss) |
| `idByName(c, path, name)` | its id, `""` on miss |
| `enable(c, path, id)` / `disable(c, path, id)` | flip the `disabled` flag |
| `moveRule(c, path, id, beforeId)` | reorder an ordered list; `""` sends it to the bottom |
| `moveRuleToTop(c, path, id)` | move to the top (no-op when already first) |
| `moveRuleToBottom(c, path, id)` | move to the bottom |
| `setVerbose(c, enabled)` → `Client` | turn command logging on/off (returns a **copy**) |
| `isVerbose(c)` → bool | whether this client logs |

Paths are normalized for you: `"interface"`, `"/interface"`, and
`"/interface/"` all mean the same thing.

```jennifer
# a path routeros has no typed helper for: DHCP options
def opts as list of map of string to string init mt.getAll($c, "/ip/dhcp-server/option");
for (def o in $opts) {
    io.printf("dhcp option %s code %s\n", $o["name"], $o["code"]);
}

# disable an item on any path by name
mt.disable($c, "/ip/upnp/interfaces",
    mt.idByName($c, "/ip/upnp/interfaces", "ether1"));
```

(Management services under `/ip/service` used to be the example here -
they now have a typed helper of their own, see
[services.md](services.md).)

Attribute maps use RouterOS's own property names (with dashes, e.g.
`"mac-address"`); values are always strings, booleans written as
`"yes"` / `"no"`.

## Verbose mode (seeing what is sent)

Turn logging on and every command the client sends is printed to stdout
just before it goes out, so a provisioning run reads back as a
transcript of what it did:

```jennifer
def c as mt.Client init mt.connect("192.168.88.1", "admin", "secret");
$c = mt.setVerbose($c, true);

mt.addBridge($c, "brlan");
mt.addIpAddress($c, "192.168.88.1/24", "brlan");
```

```
mt> /interface/bridge/add name=brlan
mt> /ip/address/add address=192.168.88.1/24 interface=brlan
```

Reads log the path and how many rows came back:

```
mt> /ip/address/print
mt< 3 rows
```

**`setVerbose` returns a copy — keep it.** A Jennifer module holds no
mutable state (`mutable def is not allowed at a module's top level`), so
there is no global switch to flip; the flag rides on the `Client` like
every other value in the deck. `mt.setVerbose($c, true);` on its own
does nothing — you must write `$c = mt.setVerbose($c, true);`.

Set the environment variable `MT_VERBOSE` to `1` / `yes` / `true` / `on`
and `connect` seeds the flag for you, which traces an existing script
without editing it:

```sh
MT_VERBOSE=1 jennifer run provision.j
```

**Credentials are never printed.** Verbose mode shows what goes on the
wire, and that includes SMTP passwords, WPA keys, IPsec and PPP secrets,
and WireGuard private keys — so those values are replaced:

```
mt> /tool/e-mail/set server=smtp.example.org user=router password=<redacted>
```

The redaction is deliberately narrow, matching `password`, `secret`,
`passphrase`, `*-password`, `*-secret`, `*-passphrase`, `private-key`,
and anything containing `pre-shared-key`. `public-key` is public,
`key-usage` is a certificate flag, and `passive` / `passthrough` merely
start with the same letters — none of those are hidden. One thing it
cannot redact: an SNMP community is sent as an ordinary `name`, so it
will appear in the log ([snmp.md](snmp.md) notes that a community
string acts like a password).

Logging covers **every** command the module sends, not just the generic
verbs — the topic files never call the transport directly, they all
funnel through the same internal chokepoint.

## Errors

- `Error{kind: "routeros"}` — routeros's own validation refused your
  input *before* anything was sent; the message says what and why.
- `Error{kind: "mikrotik"}` — the router itself refused (`!trap`), or
  the connection failed.

```jennifer
try {
    mt.addBridge($c, "br lan");           # spaces are not allowed
} catch (e) {
    io.printf("rejected: %s\n", $e.message);
    # -> rejected: the bridge name must not contain spaces
}
```

## Notes

- Everything is value-semantic (Jennifer copies on assignment); structs
  returned by routeros are snapshots, not live views.
- The shared validators (`ensureName`, `ensurePort`, `ensureMac`,
  `ensureIpAddress`, `ensureCidr`, ...) live here and are reused by all
  topic files; IP and CIDR parsing is real parsing via the stock
  `ipnet` module, not string sniffing.
