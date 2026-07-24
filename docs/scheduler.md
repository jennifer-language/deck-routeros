# Scheduler: scripts on a timer

File: `src/topics/scheduler.j`. Path: `/system/scheduler`
(`SCHEDULER_PATH`).

## Background

The scheduler runs **RouterOS script** (the language of the router's
own console) at times you define - on the router, with no outside help.
That makes it the right tool for nightly backups, periodic reboots, or
watchdog pings that must keep working when your management host is
down. The `on-event` of a task is either script source directly, or the
name of a stored `/system/script`.

Three shapes cover almost everything, and routeros has one call each:

- every N (interval),
- daily at a fixed time,
- once at every boot.

## Struct

```jennifer
mt.ScheduledTask {
    id, name,
    startTime,        # "HH:MM:SS" or "startup"
    startDate, interval,
    onEvent,          # what runs
    nextRun,          # when it fires next - the sanity check
    runCount,         # int - has it ever fired?
    disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `scheduleScript(c, name, interval, source)` → id | run every interval |
| `scheduleDaily(c, name, startTime, source)` → id | run daily at HH:MM:SS |
| `scheduleAtStartup(c, name, source)` → id | run once per boot |
| `scheduledTasks(c)` → `list of ScheduledTask` | list with nextRun / runCount |
| `removeScheduledTask(c, name)` | delete |
| `enableScheduledTask(c, name)` / `disableScheduledTask(c, name)` | pause / resume |

Intervals accept `"30s"`, `"10m"`, `"2h"`, `"1d"`, `"1w"`, combinations
(`"1d12h"`), plain seconds (`"90"`), or clock form (`"00:30:00"`);
times must be `"HH:MM:SS"`. Both are validated locally with the
expected form named in the error.

## Examples

Nightly configuration backup at 03:00:

```jennifer
mt.scheduleDaily($c, "nightly-backup", "03:00:00",
    "/system backup save name=nightly");
```

A watchdog that reboots when the uplink is gone for good (RouterOS
script inside the string):

```jennifer
mt.scheduleScript($c, "uplink-watchdog", "10m",
    ":if ([/ping 1.1.1.1 count=5] = 0) do={/system reboot}");
```

Log a marker at every boot:

```jennifer
mt.scheduleAtStartup($c, "boot-marker", ":log info \"booted\"");
```

Did my tasks actually run?

```jennifer
def tasks as list of mt.ScheduledTask init mt.scheduledTasks($c);
for (def t in $tasks) {
    io.printf("%s: every %s, next %s, ran %d times\n",
        $t.name, $t.interval, $t.nextRun, $t.runCount);
}
```

## Pitfalls

- **`on-event` is RouterOS script, not Jennifer.** routeros validates
  the timing, not the script content - a typo in the source shows up in
  the router's log at fire time, not at creation. Test one-liners in
  the RouterOS terminal first.
- Tasks run with the **policies of the user who created them** (the
  user this client logged in as). An API user without `reboot` policy
  creates a reboot task that fails silently every night.
- `runCount == 0` long after `nextRun` passed means the task errored -
  check `/log` on the router.
- Times are router-local: set the router's clock/timezone (or NTP)
  before trusting a 03:00 backup.
- Quoting inside the source string: Jennifer needs `\"` for RouterOS
  quotes, as in the boot-marker example.

## Related

- [system.md](system.md) (what you would typically schedule),
  [tools.md](tools.md) (the routeros-side alternative for watchdogs
  driven from a host).
