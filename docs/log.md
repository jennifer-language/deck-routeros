# The router log

File: `src/topics/log.j`. Paths: `/log` (`LOG_PATH`), `/system/logging`
(`LOGGING_PATH`), `/system/logging/action` (`LOGGING_ACTION_PATH`).

## Background

Two separate things hide behind "the log":

1. **The entries** live under `/log` - by default an in-memory ring
   buffer of ~1000 lines that does not survive a reboot.
2. **The rules** live under `/system/logging` - they decide which
   *topics* (categories like `firewall`, `dhcp`, `wireless`, and
   severities like `info` / `warning` / `error` / `critical`) go to
   which *action*: `memory` (the buffer), `disk`, `echo` (console), or
   `remote` (syslog).

Every entry carries its topics as a comma list (`"system,info"`), which
is what the filter helpers match on.

## Structs

```jennifer
mt.LogEntry    { id, time, topics, message }
mt.LoggingRule { id, topics, action, prefix, disabled }
```

## Functions

| Function | Purpose |
|---|---|
| `logEntries(c)` → `list of LogEntry` | the whole buffer, oldest first |
| `recentLogEntries(c, count)` | the newest N entries |
| `logEntriesWithTopic(c, topic)` | exact-word topic filter |
| `logErrors(c)` | entries with topic `error` or `critical` |
| `loggingRules(c)` → `list of LoggingRule` | what is logged where |
| `addLoggingRule(c, topics, action)` → id | route topics to an action (idempotent) |
| `removeLoggingRule(c, topics, action)` | remove that route |
| `setupRemoteLogging(c, address, port, topics)` → id | ship the log to a syslog server |

Topics lists are validated and normalized (single words, `!` negation
allowed, spaces around commas removed); actions are checked against the
router's actual action list, so custom actions work.

## Examples

The morning health check:

```jennifer
def problems as list of mt.LogEntry init mt.logErrors($c);
if (len($problems) == 0) {
    io.printf("log is clean\n");
}
for (def e in $problems) {
    io.printf("%s [%s] %s\n", $e.time, $e.topics, $e.message);
}
```

Tail the log after a change:

```jennifer
def tail as list of mt.LogEntry init mt.recentLogEntries($c, 20);
for (def e in $tail) {
    io.printf("%s %s\n", $e.time, $e.message);
}
```

Watch one subsystem - who is the DHCP server talking to?

```jennifer
def entries as list of mt.LogEntry init mt.logEntriesWithTopic($c, "dhcp");
for (def e in $entries) {
    io.printf("%s %s\n", $e.time, $e.message);
}
```

Keep firewall history on disk, and everything important on a syslog
server (see the `log` module that ships with Jennifer for the receiving
side, or any syslog daemon):

```jennifer
mt.addLoggingRule($c, "firewall", "disk");
mt.setupRemoteLogging($c, "192.168.88.40", 514, "info,warning,error,critical");
```

## Pitfalls

- **The memory log is a ring buffer** - a chatty topic pushes the
  interesting lines out fast, and a reboot clears it entirely. If you
  need history, `disk` or `remote` is not optional.
- Disk logging writes flash on most MikroTiks; on small devices point
  the heavy topics at `remote` instead and keep `disk` for the rare,
  important ones.
- Topic filters match **exact words**: `logEntriesWithTopic(c, "fire")`
  matches nothing; `"firewall"` does. Firewall rules only log when the
  rule's own log flag is set (generic `set` with `"log": "yes"`).
- `setupRemoteLogging` reconfigures the built-in `remote` action - if
  something else already ships logs to another server, this repoints
  it. Check `loggingRules(c)` first on a shared router.
- Remote syslog is plain UDP: fine on the management LAN, not across
  the internet.

## Related

- [users.md](users.md) (logins show up as `system,info` entries),
  [firewall.md](firewall.md) (rule log flags),
  [scheduler.md](scheduler.md) (failed tasks land in the log).
