# Netwatch: host monitoring

File: `src/topics/netwatch.j`. Path: `/tool/netwatch`
(`NETWATCH_PATH`).

## Background

The tools topic's `ping` answers "can the router reach X *right now*";
netwatch answers the operational questions: "is X up, since when, and
who noticed at 3 a.m.?" The router probes each watched host on an
interval, keeps the state (`up` / `down` / `unknown`) plus the time of
the last flip, and - the powerful part - can run a **RouterOS script**
on every transition. That turns the router into a tiny self-contained
monitoring system that works even when your management host is off.

Because the scripts run on state *transitions*, they fire once per
outage, not once per probe - no alert storms.

## Struct

```jennifer
mt.NetwatchHost {
    id, host,
    status,                  # "up" / "down" / "unknown" (not yet probed)
    up,                      # computed: status == "up"
    since,                   # when the current state began
    interval, timeout,
    upScript, downScript,    # RouterOS script, "" for none
    disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `watchHost(c, host, comment)` → id | start watching (router default interval; idempotent) |
| `watchHostWith(c, host, interval, comment)` → id | explicit probe interval |
| `watchHostScripted(c, host, downScript, upScript, comment)` → id | react to flips |
| `hostStatus(c, host)` → `NetwatchHost` | one host's state |
| `downHosts(c)` → `list of NetwatchHost` | everything down right now |
| `netwatchHosts(c)` → `list of NetwatchHost` | the whole watch list |
| `unwatchHost(c, host)` | stop and forget |
| `disableWatch(c, host)` / `enableWatch(c, host)` | pause / resume |

Everything is keyed by the watched host address - netwatch entries have
no names.

## Examples

Watch the important boxes:

```jennifer
mt.watchHost($c, "192.168.88.50", "printer");
mt.watchHostWith($c, "192.168.88.10", "10s", "file server");
mt.watchHost($c, "1.1.1.1", "internet reachability");
```

The morning sweep:

```jennifer
def down as list of mt.NetwatchHost init mt.downHosts($c);
if (len($down) == 0) {
    io.printf("everything is up\n");
}
for (def d in $down) {
    io.printf("%s (%s) down since %s\n", $d.host, $d.comment, $d.since);
}
```

Alert into the log (and from there to syslog - see [log.md](log.md)):

```jennifer
mt.watchHostScripted($c, "192.168.88.10",
    ":log warning \"file server went down\"",
    ":log info \"file server is back\"",
    "file server");
```

Self-healing: power-cycle a hung PoE camera when it stops answering
(RouterOS script in the down hook; see [ethernet.md](ethernet.md) for
the PoE side):

```jennifer
mt.watchHostScripted($c, "192.168.88.60",
    "/interface ethernet set ether5 poe-out=off; :delay 3; /interface ethernet set ether5 poe-out=auto-on",
    "",
    "camera watchdog");
```

## Pitfalls

- **Scripts are RouterOS script, not Jennifer**, and routeros validates
  the watch, not the script - a typo shows up in the router's log at
  flip time. Test one-liners in the RouterOS terminal first.
- Scripts run with netwatch's own (restricted, on v7) policies; a
  down-script that needs `reboot` or `write` rights may silently do
  nothing. Check `/log` after a test flip.
- A watched host that drops ICMP looks "down" while being perfectly
  alive - netwatch's default probe is a ping. RouterOS v7 adds other
  probe types (`http-get`, `tcp-conn`) via the generic `set`.
- `status == "unknown"` right after adding is normal (first probe
  pending); `downHosts` deliberately excludes it.
- Watching many hosts at aggressive intervals is load on small
  routers - 10s is plenty for most things.

## Related

- [tools.md](tools.md) (one-shot ping from the router),
  [log.md](log.md) (where script alerts land, and shipping them off),
  [scheduler.md](scheduler.md) (time-based instead of state-based
  automation), [ethernet.md](ethernet.md) (PoE power-cycling).
