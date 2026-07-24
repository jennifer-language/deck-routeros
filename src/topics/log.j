# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - the router log: reading entries, routing what gets logged.
# Spliced into routeros.j via include - not a standalone module.

/**
 * RouterOS API path of the log entries.
 *
 * The entries themselves live under "/log"; "/system/logging" (see
 * LOGGING_PATH) holds the rules that decide what gets logged where.
 */
export def const LOG_PATH as string init "/log";

/** RouterOS API path of the logging rules (topic -> action). */
export def const LOGGING_PATH as string init "/system/logging";

/** RouterOS API path of the logging actions (memory, disk, echo, remote). */
export def const LOGGING_ACTION_PATH as string init "/system/logging/action";

/**
 * One log entry.
 *
 * @field {string} id      internal RouterOS id
 * @field {string} time    when it happened, as reported (e.g. "15:33:02",
 *                         older entries carry a date prefix)
 * @field {string} topics  comma-separated topics (e.g. "system,info")
 * @field {string} message the log line itself
 */
export def struct LogEntry {
    id as string,
    time as string,
    topics as string,
    message as string
};

/**
 * One logging rule: which topics go to which action.
 *
 * @field {string} id       internal RouterOS id
 * @field {string} topics   matched topics, comma-separated ("info", "firewall", ...)
 * @field {string} action   where matching entries go ("memory", "disk",
 *                          "echo", "remote", or a custom action)
 * @field {string} prefix   text prepended to each entry, "" when unset
 * @field {bool}   disabled true when the rule is switched off
 */
export def struct LoggingRule {
    id as string,
    topics as string,
    action as string,
    prefix as string,
    disabled as bool
};

/**
 * Read the router's log (the in-memory buffer, oldest first).
 *
 * The memory log holds a limited number of entries (1000 by default) -
 * older ones are gone. For history, set up disk or remote logging
 * (`setupRemoteLogging`).
 *
 * @param {Client} c an open client
 * @return {list of LogEntry} the buffered entries
 */
export func logEntries(c as Client) {
    def rows as list of map of string to string init getAll($c, LOG_PATH);
    def out as list of LogEntry init [];
    for (def row in $rows) {
        $out[] = logEntryFromRow($row);
    }
    return $out;
}

/**
 * The newest N log entries (oldest of them first).
 *
 * @param {Client} c     an open client
 * @param {int}    count how many entries from the end of the log
 * @return {list of LogEntry} at most `count` entries
 * @throws {Error} kind "routeros" on a count below 1
 */
export func recentLogEntries(c as Client, count as int) {
    if ($count < 1) {
        raiseError("the entry count must be at least 1");
    }
    return lastEntries(logEntries($c), $count);
}

/**
 * The log entries carrying one topic (e.g. "firewall", "dhcp", "wireless").
 *
 * @param {Client} c     an open client
 * @param {string} topic the topic to filter for (one word, lowercase)
 * @return {list of LogEntry} matching entries, oldest first
 */
export func logEntriesWithTopic(c as Client, topic as string) {
    def all as list of LogEntry init logEntries($c);
    def out as list of LogEntry init [];
    for (def entry in $all) {
        if (logHasTopic($entry.topics, $topic)) {
            $out[] = $entry;
        }
    }
    return $out;
}

/**
 * The log entries that report problems (topic "error" or "critical").
 *
 * The quick health check: an empty result is good news.
 *
 * @param {Client} c an open client
 * @return {list of LogEntry} the problem entries, oldest first
 */
export func logErrors(c as Client) {
    def all as list of LogEntry init logEntries($c);
    def out as list of LogEntry init [];
    for (def entry in $all) {
        if (isProblemTopics($entry.topics)) {
            $out[] = $entry;
        }
    }
    return $out;
}

/**
 * List the logging rules: which topics are logged where.
 *
 * @param {Client} c an open client
 * @return {list of LoggingRule} all rules
 */
export func loggingRules(c as Client) {
    def rows as list of map of string to string init getAll($c, LOGGING_PATH);
    def out as list of LoggingRule init [];
    for (def row in $rows) {
        $out[] = loggingRuleFromRow($row);
    }
    return $out;
}

/**
 * Log the given topics to an action.
 *
 * Topics are RouterOS log categories ("firewall", "dhcp", "wireless",
 * severity levels like "info" / "warning" / "error", combinable and
 * negatable: "info,!dns"). The action must exist on the router -
 * built-ins are "memory", "disk", "echo", "remote". Idempotent: an
 * identical rule is reused, not duplicated.
 *
 * @param {Client} c      an open client
 * @param {string} topics comma-separated topics to match
 * @param {string} action where matching entries go
 * @return {string} the RouterOS id of the (new or existing) rule
 * @throws {Error} kind "routeros" on empty topics or an unknown action
 * @example
 *   mt.addLoggingRule($c, "firewall", "disk");
 */
export func addLoggingRule(c as Client, topics as string, action as string) {
    def wanted as string init normalizedLogTopics($topics);
    requiredId($c, LOGGING_ACTION_PATH, $action, "logging action");
    def rows as list of map of string to string init getAll($c, LOGGING_PATH);
    def existing as map of string to string init findLoggingRow($rows, $wanted, $action);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    return add($c, LOGGING_PATH, {"topics": $wanted, "action": $action});
}

/**
 * Remove the logging rule sending some topics to an action.
 *
 * @param {Client} c      an open client
 * @param {string} topics the rule's topics, as given to `addLoggingRule`
 * @param {string} action the rule's action
 * @throws {Error} kind "routeros" when no such rule exists
 */
export func removeLoggingRule(c as Client, topics as string, action as string) {
    def wanted as string init normalizedLogTopics($topics);
    def rows as list of map of string to string init getAll($c, LOGGING_PATH);
    def row as map of string to string init findLoggingRow($rows, $wanted, $action);
    if (len($row) == 0) {
        raiseError("no logging rule sends \"" + $wanted + "\" to \"" + $action + "\"");
    }
    remove($c, LOGGING_PATH, rowValue($row, ".id"));
}

/**
 * Ship the router's log to a remote syslog server.
 *
 * Points the built-in "remote" action at the server (UDP syslog) and
 * routes the given topics there. Idempotent. The memory log keeps
 * working alongside - remote logging is an addition, not a replacement.
 *
 * @param {Client} c       an open client
 * @param {string} address the syslog server's IP address
 * @param {int}    port    its UDP port (514 is the syslog standard)
 * @param {string} topics  what to ship (e.g. "info,warning,error,critical")
 * @return {string} the RouterOS id of the logging rule
 * @throws {Error} kind "routeros" on a malformed address, port, or topics
 * @example
 *   mt.setupRemoteLogging($c, "192.168.88.40", 514, "info,warning,error,critical");
 */
export func setupRemoteLogging(c as Client, address as string, port as int, topics as string) {
    ensureIpAddress($address);
    ensurePort($port);
    def actionId as string init requiredId($c, LOGGING_ACTION_PATH, "remote", "logging action");
    set($c, LOGGING_ACTION_PATH, $actionId,
        {"remote": strings.trim($address), "remote-port": convert.toString($port)});
    return addLoggingRule($c, $topics, "remote");
}

/**
 * The last `count` elements of an entry list.
 *
 * @param {list of LogEntry} entries the full list, oldest first
 * @param {int} count how many from the end (already validated >= 1)
 * @return {list of LogEntry} the tail, order preserved
 * @internal
 */
func lastEntries(entries as list of LogEntry, count as int) {
    if (len($entries) <= $count) {
        return $entries;
    }
    return $entries[len($entries) - $count..];
}

/**
 * Test whether a comma-separated topic list contains one topic.
 *
 * @param {string} topicsCsv the entry's topics (e.g. "system,info")
 * @param {string} topic     the topic to look for (exact word)
 * @return {bool} true when present
 * @internal
 */
func logHasTopic(topicsCsv as string, topic as string) {
    def parts as list of string init strings.split($topicsCsv, ",");
    for (def part in $parts) {
        if (strings.trim($part) == $topic) {
            return true;
        }
    }
    return false;
}

/**
 * Test whether a topic list marks a problem entry.
 *
 * @param {string} topicsCsv the entry's topics
 * @return {bool} true on "error" or "critical"
 * @internal
 */
func isProblemTopics(topicsCsv as string) {
    return logHasTopic($topicsCsv, "error") or logHasTopic($topicsCsv, "critical");
}

/**
 * Validate and normalize a logging-topics list.
 *
 * Entries are single lowercase words, optionally "!"-negated
 * ("info,!dns"); spaces around commas are tolerated and removed.
 *
 * @param {string} csv the candidate list
 * @return {string} the normalized list
 * @throws {Error} kind "routeros" on an empty list or a malformed entry
 * @internal
 */
func normalizedLogTopics(csv as string) {
    def parts as list of string init strings.split($csv, ",");
    def out as list of string init [];
    for (def part in $parts) {
        def p as string init strings.trim($part);
        if ($p == "") {
            raiseError("the topics list \"" + $csv + "\" must not contain empty entries");
        }
        if (strings.contains($p, " ")) {
            raiseError("the topic \"" + $p + "\" must be a single word (e.g. \"firewall\", \"info\", \"!dns\")");
        }
        $out[] = $p;
    }
    if (len($out) == 0) {
        raiseError("the topics list must contain at least one topic");
    }
    return strings.join($out, ",");
}

/**
 * Find the rule matching a normalized topics list and an action.
 *
 * @param {list of map of string to string} rows "/system/logging/print" rows
 * @param {string} topics the normalized topics list
 * @param {string} action the action name
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func findLoggingRow(rows as list of map of string to string, topics as string, action as string) {
    for (def row in $rows) {
        if (rowValue($row, "topics") == $topics and rowValue($row, "action") == $action) {
            return $row;
        }
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Fold a reply row into a LogEntry.
 *
 * @param {map of string to string} row a "/log/print" row
 * @return {LogEntry} the typed entry
 * @internal
 */
func logEntryFromRow(row as map of string to string) {
    return LogEntry{
        id: rowValue($row, ".id"),
        time: rowValue($row, "time"),
        topics: rowValue($row, "topics"),
        message: rowValue($row, "message")
    };
}

/**
 * Fold a reply row into a LoggingRule.
 *
 * @param {map of string to string} row a "/system/logging/print" row
 * @return {LoggingRule} the typed rule
 * @internal
 */
func loggingRuleFromRow(row as map of string to string) {
    return LoggingRule{
        id: rowValue($row, ".id"),
        topics: rowValue($row, "topics"),
        action: rowValue($row, "action"),
        prefix: rowValue($row, "prefix"),
        disabled: rowBool($row, "disabled")
    };
}
