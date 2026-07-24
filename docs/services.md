# Management services

File: `src/topics/services.j`. Path: `/ip/service` (`SERVICE_PATH`).

## Background

`/ip/service` is the fixed list of doors into the router: `api` and
`api-ssl` (what routeros itself uses), `ssh`, `winbox`, `www` and
`www-ssl` (WebFig), plus the cleartext relics `telnet` and `ftp`.
Services are never added or removed - only enabled, disabled, moved to
other ports, and restricted to source networks.

Hardening a MikroTik largely happens right here, in three moves:

1. **Close what you don't use** - especially telnet and ftp, which
   send passwords in cleartext.
2. **Restrict what you do use** to the management networks.
3. Optionally **move noisy ports** (ssh, winbox) - that cuts scanner
   noise, but is obscurity, not security; the restriction does the
   protecting.

## Struct

```jennifer
mt.Service {
    id, name,
    port,          # int
    address,       # allowed sources, "" = anywhere
    certificate,   # ssl services, "" otherwise
    invalid,       # misconfigured (e.g. ssl without cert) - not running
    disabled
}
```

## Functions

| Function | Purpose |
|---|---|
| `services(c)` → `list of Service` | the audit view |
| `serviceByName(c, name)` → `Service` | one service |
| `enableService(c, name)` / `disableService(c, name)` | open / close a door |
| `setServicePort(c, name, port)` | move a service (clashes refused, owner named) |
| `restrictService(c, name, addresses)` | limit sources to IPs/CIDRs; `""` lifts |
| `disableInsecureServices(c)` → count | switch off telnet + ftp |

Service names are validated against the fixed list, so a typo fails
with the choices spelled out.

## Examples

The standard hardening pass:

```jennifer
mt.disableInsecureServices($c);                       # telnet + ftp off
mt.restrictService($c, "winbox", "10.0.9.0/24");      # management net only
mt.restrictService($c, "ssh", "10.0.9.0/24");
mt.restrictService($c, "api-ssl", "10.0.9.0/24");
mt.disableService($c, "www");                         # WebFig over TLS only
```

The audit:

```jennifer
def svcs as list of mt.Service init mt.services($c);
for (def s in $svcs) {
    if (not $s.disabled and $s.address == "") {
        io.printf("open to the world: %s on port %d\n", $s.name, $s.port);
    }
}
```

Move ssh out of the scan storm:

```jennifer
mt.setServicePort($c, "ssh", 2200);
# ssh to the router now needs -p 2200; the restriction above still applies
```

## Pitfalls

- **Do not close the door you came through.** Disabling (or
  mis-restricting) the API service carrying this session disconnects
  you - and if it was your only way in, the next step is a serial
  cable. Change `api` from an `api-ssl` session and vice versa, and
  always verify one other access path (winbox/ssh) works first.
- `restrictService` applies to *new* connections; your current session
  survives a mistake, so test a fresh connection before logging out.
- A service with `invalid == true` (typically `api-ssl`/`www-ssl`
  without a certificate) is enabled but not actually listening -
  enabling it is not enough, it needs a certificate (generic verbs,
  `/certificate`).
- The services listen on **all** addresses the router has, including
  the WAN, unless restricted - a fresh router answers WinBox from the
  internet. Restriction here and/or an input-chain firewall rule
  ([firewall.md](firewall.md)) both work; doing both is fine.
- MAC-WinBox and MAC-Telnet (`/tool/mac-server`, generic verbs) are
  separate LAN-only doors that ignore these settings.

## Related

- [users.md](users.md) (who may log in; `restrictUser` is the same
  idea per account), [firewall.md](firewall.md) (the other layer of
  the same defence), [core.md](core.md) (the api service is what
  routeros connects through).
