<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# Scripts (the repository)

File: `src/topics/script.j`. Path: `/system/script` (`SCRIPT_PATH`).

## Background

`/system/script` is the router's named-script store. Where the
[scheduler](scheduler.md) can take script *source* inline, storing a
script once and referring to it *by name* is cleaner for anything reused
or long: the scheduler, [netwatch](netwatch.md), and on-demand
`runScript` all run a stored script by name, and it lives in one place
to edit. The source is **RouterOS scripting**, not Jennifer.

## Struct

```jennifer
mt.Script { id, name, source, policy, runCount, lastStarted, comment }
```

## Functions

| Function | Purpose |
|---|---|
| `scripts(c)` → `list of Script` | the whole repository |
| `scriptByName(c, name)` → `Script` | one script |
| `addScript(c, name, source, comment)` → id | store a script (name must be free) |
| `updateScript(c, name, source)` | replace its source |
| `runScript(c, name)` → string | run it now, returns its return value |
| `removeScript(c, name)` | delete it |

## Examples

Store once, schedule by name:

```jennifer
mt.addScript($c, "nightly",
    "/system backup save name=nightly", "nightly config backup");
mt.scheduleDaily($c, "run-nightly", "03:00:00", "nightly");   # scheduler runs it by name
```

Run on demand and read the result:

```jennifer
mt.addScript($c, "wan-ip",
    ":put [/ip/cloud/get public-address]", "print the WAN IP");
def ip as string init mt.runScript($c, "wan-ip");
io.printf("WAN IP: %s\n", $ip);
```

Update a script in place:

```jennifer
mt.updateScript($c, "nightly",
    "/system backup save name=nightly password=secret");
```

## Pitfalls

- **RouterOS script, not Jennifer** — routeros validates the name and
  that the source is non-empty, not the script's correctness. A syntax
  error or a missing permission surfaces in the router log at run time.
  Test one-liners in the RouterOS terminal first.
- **Policies:** a script runs with its own `policy` (permission set). A
  script that reboots or writes config needs those policies, and the
  *user* creating/running it needs them too — otherwise it silently does
  nothing.
- **Deleting a script breaks schedules that call it by name** — remove
  or repoint the scheduler entry too.
- **Quoting:** RouterOS quotes inside the source need `\"` in the
  Jennifer string (see the log-message examples).

## Related

- [scheduler.md](scheduler.md) (run stored scripts on a timer),
  [netwatch.md](netwatch.md) (on state change),
  [tools.md](tools.md) (`sendEmail` from a script),
  [users.md](users.md) (policies).
