# Clock & NTP

File: `src/topics/clock.j`. Paths: `/system/clock` (`CLOCK_PATH`),
`/system/ntp/client` (`NTP_CLIENT_PATH`).

## Background

MikroTik routers have **no battery-backed clock**: every boot starts at
the firmware's build date until something sets the time. A wrong clock
is quietly poisonous - certificates fail validation
([certificates.md](certificates.md)), scheduled tasks fire at fantasy
times ([scheduler.md](scheduler.md)), and log timestamps become
fiction. `useNtp` + `setTimezone` therefore belong in every base
config, right after the WAN comes up.

## Structs

```jennifer
mt.Clock     { time, date, timezone, autodetect, gmtOffset }
mt.NtpStatus { enabled, servers, status, synced }   # synced computed
```

## Functions

| Function | Purpose |
|---|---|
| `useNtp(c, servers)` | enable the NTP client (DNS names or IPs, comma-separated) |
| `setTimezone(c, timezone)` | IANA name ("Europe/Berlin") or "UTC" |
| `clock(c)` → `Clock` | what time the router thinks it is |
| `ntpStatus(c)` → `NtpStatus` | is it actually syncing? check `synced` |
| `disableNtp(c)` | stop syncing (rarely what you want) |

## Examples

The base-config pair:

```jennifer
mt.useNtp($c, "pool.ntp.org");
mt.setTimezone($c, "Europe/Berlin");
```

Verify before trusting anything time-based:

```jennifer
def st as mt.NtpStatus init mt.ntpStatus($c);
if (not $st.synced) {
    io.printf("clock not synced yet (%s) - certificates and schedules unreliable\n", $st.status);
}
def ck as mt.Clock init mt.clock($c);
io.printf("router time: %s %s (%s)\n", $ck.date, $ck.time, $ck.timezone);
```

## Pitfalls

- NTP by DNS name requires working resolver settings
  ([dns.md](dns.md)) - on a fresh router set DNS first, or use IPs.
- The v7 NTP client shape is used (`servers` list); v6 had
  `primary-ntp`/`secondary-ntp` (IPs only) - drive v6 with the generic
  verbs if you still run it.
- `synced` takes a minute after enabling; don't fail a provisioning
  script on the first check.
- An isolated network needs an internal NTP source - the router can
  also *serve* NTP (`/system/ntp/server`, generic verbs).

## Related

- [certificates.md](certificates.md), [scheduler.md](scheduler.md),
  [log.md](log.md), [dns.md](dns.md).
