<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# LTE / cellular

File: `src/topics/lte.j`. Paths: `/interface/lte` (`LTE_PATH`),
`/interface/lte/apn` (`LTE_APN_PATH`).

## Background

A cellular modem gives the router a mobile-broadband uplink - the
classic **backup WAN** (fail over to LTE when the wired line dies) or
the primary link at a site with no wired internet. Two things determine
whether it works: the **APN** (the carrier's access-point name, from the
SIM's provider) and the **signal** (placement and antenna). This topic
reads the interface, measures the live signal, and sets the APN;
returns empty on routers with no modem.

## Structs

```jennifer
mt.LteInterface { id, name, running, disabled, comment }
mt.LteStatus {
    status, registered,          # registered computed from status
    operator, accessTechnology,  # "lte" / "5g" / ...
    signalStrength, rsrp, rsrq, sinr
}
```

## Functions

| Function | Purpose |
|---|---|
| `lteInterfaces(c)` → `list of LteInterface` | the modem(s), empty if none |
| `lteStatus(c, name)` → `LteStatus` | live registration + signal |
| `setLteApn(c, name, apn)` | set the carrier APN |
| `enableLte(c, name)` / `disableLte(c, name)` | up / down |

## Examples

Is the cellular link healthy?

```jennifer
def s as mt.LteStatus init mt.lteStatus($c, "lte1");
io.printf("%s on %s (%s)\n", $s.status, $s.operator, $s.accessTechnology);
io.printf("RSRP %s, RSRQ %s, SINR %s\n", $s.rsrp, $s.rsrq, $s.sinr);
if (not $s.registered) { io.printf("not on the network - check SIM/antenna\n"); }
```

Set the APN (the usual "registered but no data" fix):

```jennifer
mt.setLteApn($c, "lte1", "internet");
```

LTE as a backup WAN, in one picture: give it a route with a higher
distance than the primary ([routing.md](routing.md)), masquerade it
([nat.md](nat.md)), and let distance-based failover switch to it when
the primary gateway dies - optionally watch the primary with
[netwatch.md](netwatch.md).

## Pitfalls

- **Signal reality check:** RSRP better than about −90 dBm is good,
  −100 to −110 is marginal, worse drops out. An external antenna and
  moving the router to a window fix more than any config.
- **APN comes from the carrier** - a wrong one registers on the network
  but passes no data. Some SIMs need a username/password too (generic
  verbs on the APN profile).
- **Data caps:** as a *backup*, make sure normal traffic doesn't
  silently ride the LTE link (check the route distances) or a metered
  SIM burns through its cap.
- 5G/technology and band locking, SIM PIN, and roaming are set via the
  generic verbs on the interface.

## Related

- [routing.md](routing.md) (failover by distance), [nat.md](nat.md),
  [netwatch.md](netwatch.md), [ethernet.md](ethernet.md) (the wired WAN
  it backs up).
