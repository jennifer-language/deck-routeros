# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - netwatch: the router keeps an eye on hosts for you.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the netwatch host list. */
export def const NETWATCH_PATH as string init "/tool/netwatch";

/**
 * One watched host: the router probes it continuously and tracks state.
 *
 * @field {string} id         internal RouterOS id
 * @field {string} host       the address being watched
 * @field {string} status     "up", "down", or "unknown" (not yet probed)
 * @field {bool}   up         computed: the status equals "up"
 * @field {string} since      when the current state began - "down since
 *                            yesterday 03:12" is the useful half of an outage report
 * @field {string} interval   time between probes as reported
 * @field {string} timeout    probe timeout as reported
 * @field {string} upScript   RouterOS script run when the host comes up, "" for none
 * @field {string} downScript RouterOS script run when the host goes down, "" for none
 * @field {bool}   disabled   true when the watch is switched off
 * @field {string} comment    free-text comment, "" when unset
 */
export def struct NetwatchHost {
    id as string,
    host as string,
    status as string,
    up as bool,
    since as string,
    interval as string,
    timeout as string,
    upScript as string,
    downScript as string,
    disabled as bool,
    comment as string
};

/**
 * List every watched host with its current state.
 *
 * @param {Client} c an open client
 * @return {list of NetwatchHost} all netwatch entries
 */
export func netwatchHosts(c as Client) {
    def rows as list of map of string to string init getAll($c, NETWATCH_PATH);
    def out as list of NetwatchHost init [];
    for (def row in $rows) {
        $out[] = netwatchFromRow($row);
    }
    return $out;
}

/**
 * Start watching a host (probing at the router's default interval).
 *
 * Idempotent: if the host is already watched, the existing entry's id
 * is returned.
 *
 * @param {Client} c       an open client
 * @param {string} host    the address to watch (e.g. "192.168.88.50")
 * @param {string} comment friendly note (e.g. "printer") - "" for none
 * @return {string} the RouterOS id of the (new or existing) entry
 * @throws {Error} kind "routeros" on an empty or malformed host
 * @example
 *   mt.watchHost($c, "192.168.88.50", "printer");
 */
export func watchHost(c as Client, host as string, comment as string) {
    return netwatchAdd($c, $host, "", "", "", $comment);
}

/**
 * Start watching a host, probing every `interval`.
 *
 * @param {Client} c        an open client
 * @param {string} host     the address to watch
 * @param {string} interval time between probes: "10s", "1m", "5m", ...
 * @param {string} comment  friendly note - "" for none
 * @return {string} the RouterOS id of the (new or existing) entry
 * @throws {Error} kind "routeros" on a bad host or interval
 */
export func watchHostWith(c as Client, host as string, interval as string, comment as string) {
    def every as string init strings.trim($interval);
    ensureSchedulerInterval($every);
    return netwatchAdd($c, $host, $every, "", "", $comment);
}

/**
 * Watch a host and react to state changes with RouterOS scripts.
 *
 * The scripts are the alerting hook: log, send an email, flip a route,
 * power-cycle a PoE port - whatever the situation calls for. They run
 * ON THE ROUTER (RouterOS script, not Jennifer) whenever the state
 * flips; at least one of the two must be given.
 *
 * @param {Client} c          an open client
 * @param {string} host       the address to watch
 * @param {string} downScript RouterOS script run when the host goes down, "" for none
 * @param {string} upScript   RouterOS script run when it comes back, "" for none
 * @param {string} comment    friendly note - "" for none
 * @return {string} the RouterOS id of the (new or existing) entry
 * @throws {Error} kind "routeros" on a bad host or when both scripts are empty
 * @example
 *   mt.watchHostScripted($c, "192.168.88.50",
 *       ":log warning \"printer went down\"",
 *       ":log info \"printer is back\"",
 *       "printer");
 */
export func watchHostScripted(
    c as Client,
    host as string,
    downScript as string,
    upScript as string,
    comment as string) {
    if (strings.trim($downScript) == "" and strings.trim($upScript) == "") {
        raiseError("give at least one of downScript / upScript - otherwise use watchHost");
    }
    return netwatchAdd($c, $host, "", $downScript, $upScript, $comment);
}

/**
 * Read the state of one watched host.
 *
 * @param {Client} c    an open client
 * @param {string} host the watched address
 * @return {NetwatchHost} the entry; check `up` and `since`
 * @throws {Error} kind "routeros" when the host is not being watched
 */
export func hostStatus(c as Client, host as string) {
    def rows as list of map of string to string init getAll($c, NETWATCH_PATH);
    def row as map of string to string init findRowByField($rows, "host", strings.trim($host));
    if (len($row) == 0) {
        raiseError("\"" + $host + "\" is not being watched - start with watchHost");
    }
    return netwatchFromRow($row);
}

/**
 * The watched hosts that are down right now.
 *
 * The morning sweep: an empty list is good news. Hosts still in
 * "unknown" state (just added, not yet probed) are not included.
 *
 * @param {Client} c an open client
 * @return {list of NetwatchHost} the down hosts, with their `since`
 */
export func downHosts(c as Client) {
    def all as list of NetwatchHost init netwatchHosts($c);
    def out as list of NetwatchHost init [];
    for (def entry in $all) {
        if ($entry.status == "down") {
            $out[] = $entry;
        }
    }
    return $out;
}

/**
 * Stop watching a host and forget its entry.
 *
 * @param {Client} c    an open client
 * @param {string} host the watched address
 * @throws {Error} kind "routeros" when the host is not being watched
 */
export func unwatchHost(c as Client, host as string) {
    remove($c, NETWATCH_PATH, requiredNetwatchId($c, $host));
}

/**
 * Pause the watch on a host (entry and scripts kept).
 *
 * @param {Client} c    an open client
 * @param {string} host the watched address
 * @throws {Error} kind "routeros" when the host is not being watched
 */
export func disableWatch(c as Client, host as string) {
    disable($c, NETWATCH_PATH, requiredNetwatchId($c, $host));
}

/**
 * Resume the watch on a host.
 *
 * @param {Client} c    an open client
 * @param {string} host the watched address
 * @throws {Error} kind "routeros" when the host is not being watched
 */
export func enableWatch(c as Client, host as string) {
    enable($c, NETWATCH_PATH, requiredNetwatchId($c, $host));
}

/**
 * Validate and create (or reuse) a netwatch entry.
 *
 * @param {Client} c          an open client
 * @param {string} host       the address to watch
 * @param {string} interval   probe interval, "" for the router default
 * @param {string} downScript on-down script, "" for none
 * @param {string} upScript   on-up script, "" for none
 * @param {string} comment    note, "" for none
 * @return {string} the RouterOS id of the (new or existing) entry
 * @throws {Error} kind "routeros" on a bad host
 * @internal
 */
func netwatchAdd(
    c as Client,
    host as string,
    interval as string,
    downScript as string,
    upScript as string,
    comment as string) {
    def target as string init strings.trim($host);
    ensureHost($target);
    def rows as list of map of string to string init getAll($c, NETWATCH_PATH);
    def existing as map of string to string init findRowByField($rows, "host", $target);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    def attrs as map of string to string init {"host": $target};
    if ($interval != "") {
        $attrs["interval"] = $interval;
    }
    if (strings.trim($downScript) != "") {
        $attrs["down-script"] = $downScript;
    }
    if (strings.trim($upScript) != "") {
        $attrs["up-script"] = $upScript;
    }
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, NETWATCH_PATH, $attrs);
}

/**
 * Resolve a watched host to its entry id, with a friendly error.
 *
 * @param {Client} c    an open client
 * @param {string} host the watched address
 * @return {string} the entry id
 * @throws {Error} kind "routeros" when the host is not being watched
 * @internal
 */
func requiredNetwatchId(c as Client, host as string) {
    def rows as list of map of string to string init getAll($c, NETWATCH_PATH);
    def row as map of string to string init findRowByField($rows, "host", strings.trim($host));
    if (len($row) == 0) {
        raiseError("\"" + $host + "\" is not being watched - start with watchHost");
    }
    return rowValue($row, ".id");
}

/**
 * Fold a reply row into a NetwatchHost.
 *
 * `up` is computed here: the status equals "up".
 *
 * @param {map of string to string} row a "/tool/netwatch/print" row
 * @return {NetwatchHost} the typed entry
 * @internal
 */
func netwatchFromRow(row as map of string to string) {
    def status as string init rowValue($row, "status");
    return NetwatchHost{
        id: rowValue($row, ".id"),
        host: rowValue($row, "host"),
        status: $status,
        up: $status == "up",
        since: rowValue($row, "since"),
        interval: rowValue($row, "interval"),
        timeout: rowValue($row, "timeout"),
        upScript: rowValue($row, "up-script"),
        downScript: rowValue($row, "down-script"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
