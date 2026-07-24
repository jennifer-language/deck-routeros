# routeros

A **thick layer over the MikroTik RouterOS API** for the
[Jennifer](https://jennifer-lang.dev/) language.

The bundled `mikrotik` module speaks the raw binary API: command paths,
`=key=value` words, reply sentences. routeros wraps that in plain verbs and
typed structs so you can configure interfaces, bridges, and the firewall
without knowing RouterOS internals. All input is validated before it touches
the wire; every failure is an `Error{kind: "routeros"}` (or
`kind: "mikrotik"` from the transport) with a human-readable message.

## Usage

```jennifer
import "./src/routeros.j" as mt;

def c as mt.Client init mt.connect("192.168.88.1", "admin", "secret");

# bridges
mt.addBridge($c, "brlan");
mt.addBridgePort($c, "brlan", "ether2");

# interfaces
mt.disableInterface($c, "ether5");
mt.commentInterface($c, "ether1", "uplink");

# firewall
mt.allowService($c, "tcp", 22, "ssh management");
mt.blockAddress($c, "203.0.113.7", "known scanner");

def r as mt.FirewallRule init mt.firewallRule(mt.CHAIN_FORWARD, mt.ACTION_DROP);
$r = mt.withProtocol($r, "tcp");
$r = mt.withDstPort($r, "445");
$r = mt.withComment($r, "no smb forwarding");
mt.addFirewallRule($c, $r);

mt.disconnect($c);
```

See [`examples/`](examples/) for one runnable example per topic, e.g.
`MT_HOST=... MT_USER=... MT_PASSWORD=... jennifer run examples/firewall.j`.

## Documentation

- [docs/cheatsheet.md](docs/cheatsheet.md) — the full API surface, project layout, tests, requirements
- [docs/README.md](docs/README.md) — per-topic guides with background and worked examples
- [examples/](examples/) — one runnable, read-only example per topic (`examples/<topic>.j`)
- [RouterOS documentation](https://help.mikrotik.com/docs/) — MikroTik's official reference for
  everything behind the paths this module wraps

## Disclaimer

MikroTik and RouterOS are trademarks of SIA Mikrotīkls. This project is
an independent, community-written client library; it is **not
affiliated with, endorsed, or supported by SIA Mikrotīkls**. It
configures live network equipment — review what a call does before
pointing it at production hardware. **Use at your own risk**; no
warranty of any kind.

## License

Licensed under the **GNU LGPL v3.0 only** — see [LICENSE.md](LICENSE.md).
Copyright © 2026 mplx &lt;jennifer@mplx.dev&gt;. Every source file carries
an `SPDX-License-Identifier: LGPL-3.0-only` header.
