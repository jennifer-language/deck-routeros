<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# CAPsMAN: central WiFi management

File: `src/topics/capsman.j`. Paths: legacy `/caps-man/*`
(`CAPSMAN_PATH`, `CAPSMAN_REGISTRATION_PATH`, `CAPSMAN_REMOTE_PATH`),
CAPsMANv2 `/interface/wifi/capsman`, `/interface/wifi/cap`
(`WIFI_CAPSMAN_PATH`, `WIFI_CAP_PATH`).

## Background

Configuring ten access points by hand is ten chances to fumble a
password. CAPsMAN makes one router the *controller* (CAPsMAN) and turns
the APs into *CAPs* that download their SSID, security, and channel plan
from it - change the WiFi password once, every AP updates, and clients
roam between them seamlessly.

RouterOS has **two incompatible generations**:

- **legacy** `/caps-man` - for classic-wireless hardware
  ([wireless.md](wireless.md));
- **CAPsMANv2** under `/interface/wifi` - for wifiwave2/ax hardware
  ([wifi.md](wifi.md)).

This topic reports and toggles whichever the router has; `version` on
the status says which (0 = neither).

## Structs

```jennifer
mt.CapsmanStatus { enabled, version, managedAps }   # version 1 / 2 / 0
mt.ManagedAp { identity, address, interfaceName, state }
```

## Functions

| Function | Purpose |
|---|---|
| `capsmanStatus(c)` → `CapsmanStatus` | on/off, generation, AP count |
| `enableCapsman(c)` / `disableCapsman(c)` | turn the controller on/off |
| `managedAps(c)` → `list of ManagedAp` | the APs it manages |

## Example

```jennifer
def st as mt.CapsmanStatus init mt.capsmanStatus($c);
if ($st.version == 0) { io.printf("no CAPsMAN on this router\n"); }
else { io.printf("CAPsMAN v%d, %d APs\n", $st.version, $st.managedAps); }

mt.enableCapsman($c);   # step one only - see below

def aps as list of mt.ManagedAp init mt.managedAps($c);
for (def ap in $aps) { io.printf("%s at %s: %s\n", $ap.identity, $ap.address, $ap.state); }
```

## The substance stays with the generic verbs

Enabling the manager is only step one. The *configuration* (SSID,
security, datapath/bridge) and the *provisioning* rules (which config a
joining AP receives) are where a CAPsMAN setup lives - and their shape
differs sharply between the two generations
(`/caps-man/configuration` + `/caps-man/provisioning` vs.
`/interface/wifi/configuration` + `/interface/wifi/provisioning`). This
topic deliberately does not paper over that difference; build those with
the generic verbs against your generation. On the AP side, the CAP is
enabled with `/interface/wifi/cap set enabled=yes` (v2) or the classic
`/interface/wireless/cap` (v1), pointing at the manager.

## Pitfalls

- **Know your generation first** - `capsmanStatus(c).version` tells you.
  Mixing v1 config on v2 hardware (or vice versa) simply does nothing.
- **The controller needs a reachable, stable address** the CAPs find
  (CAPsMAN discovery, or a configured address) - usually on the
  management VLAN.
- Enabling the manager without a configuration + provisioning rule
  leaves joining APs unprovisioned (they register but broadcast
  nothing).
- A CAP under management ignores its local WiFi settings - configure the
  controller, not the AP.

## Related

- [wireless.md](wireless.md) (classic radios), [wifi.md](wifi.md)
  (wifiwave2), [bridges.md](bridges.md) / [vlans.md](vlans.md) (the
  datapath the SSIDs land on).
