<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# System health

File: `src/topics/health.j`. Path: `/system/health`
(`SYSTEM_HEALTH_PATH`).

## Background

Bigger MikroTiks expose hardware sensors - CPU and board temperatures,
supply voltage, fan RPM, PSU state. On a small home router there may be
none. This topic reads whatever the model reports; an empty result is
normal, not an error.

## Struct

```jennifer
mt.HealthSensor { name, value, kind }   # kind = "C" / "V" / "RPM" ...
```

## Functions

| Function | Purpose |
|---|---|
| `healthSensors(c)` → `list of HealthSensor` | every sensor the model has |
| `healthValue(c, name)` → string | one reading, `""` when absent |

## Examples

```jennifer
def sensors as list of mt.HealthSensor init mt.healthSensors($c);
if (len($sensors) == 0) { io.printf("this model reports no sensors\n"); }
for (def s in $sensors) {
    io.printf("%s: %s %s\n", $s.name, $s.value, $s.kind);
}

def cpu as string init mt.healthValue($c, "cpu-temperature");
if ($cpu != "") { io.printf("CPU is at %s C\n", $cpu); }
```

Feed it to monitoring by pairing with the scheduler (log a warning past
a threshold) or [SNMP](snmp.md) (which exposes the same sensors to your
monitoring system).

## Pitfalls

- **Sensor names and units vary by model** - do not hard-code a name
  without checking `healthSensors` on the actual hardware. Values are
  strings as reported (RouterOS 7 normalizes many to plain numbers).
- No sensors ≠ a problem; it just means the board has none exposed.
- For alerting, threshold logic is yours (compare `healthValue`), or let
  a monitoring system poll via SNMP.

## Related

- [snmp.md](snmp.md) (the same data to external monitoring),
  [scheduler.md](scheduler.md) (threshold alerts on the router),
  [system.md](system.md) (version, uptime, load).
