<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# Traffic flow (NetFlow / IPFIX)

File: `src/topics/trafficflow.j`. Paths: `/ip/traffic-flow`
(`TRAFFIC_FLOW_PATH`), `/ip/traffic-flow/target`
(`TRAFFIC_FLOW_TARGET_PATH`).

## Background

Traffic flow exports a record for every connection the router sees to an
external **collector** — ntopng, Elastiflow, SolarWinds, a commercial
appliance — which turns them into bandwidth graphs, top-talker lists,
and per-application breakdowns. It is the "where is my bandwidth going"
tool, and unlike SNMP (which gives interface totals) it sees individual
flows. Two steps: enable accounting, and point it at a collector.

## Structs

```jennifer
mt.TrafficFlowSettings { enabled, interfaces }
mt.FlowTarget { id, address, port, version, disabled }
```

## Functions

| Function | Purpose |
|---|---|
| `trafficFlowStatus(c)` → `TrafficFlowSettings` | on/off + accounted interfaces |
| `enableTrafficFlow(c)` / `disableTrafficFlow(c)` | switch accounting |
| `flowTargets(c)` → `list of FlowTarget` | the collectors |
| `addFlowTarget(c, address, port, version)` → id | export to a collector (idempotent) |
| `removeFlowTarget(c, address)` | remove one |

`version` is `"5"` (widest legacy compatibility), `"9"`, or `"ipfix"`
(the modern standard).

## Example

```jennifer
mt.enableTrafficFlow($c);                              # account all interfaces
mt.addFlowTarget($c, "10.0.9.30", 2055, "ipfix");      # ntopng / Elastiflow

def ts as list of mt.FlowTarget init mt.flowTargets($c);
for (def t in $ts) { io.printf("export v%s -> %s:%s\n", $t.version, $t.address, $t.port); }
```

## Pitfalls

- **Both steps are needed** — enabling accounting without a target
  measures into the void; a target without `enabled=yes` exports
  nothing.
- **The collector must speak the version you pick** — match it to your
  tool (most modern collectors prefer `ipfix` or NetFlow v9; v5 is the
  fallback).
- **Overhead:** flow accounting adds per-connection work — negligible on
  most boxes, noticeable on a small CPU under heavy connection churn.
- Flow export is UDP and unencrypted — keep the collector on a trusted
  segment.

## Related

- [snmp.md](snmp.md) (interface-level counters, the coarser view),
  [contrack.md](contrack.md) (the live connections being accounted),
  [mangle.md](mangle.md) (mark traffic to classify it in the collector).
