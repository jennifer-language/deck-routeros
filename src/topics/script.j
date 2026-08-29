# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - the script repository: named RouterOS scripts.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the script repository. */
export def const SCRIPT_PATH as string init "/system/script";

/**
 * One stored RouterOS script.
 *
 * @field {string} id          internal RouterOS id
 * @field {string} name        the script name (how the scheduler / netwatch refer to it)
 * @field {string} source      the RouterOS script source
 * @field {string} policy      the permissions it runs with, comma-separated
 * @field {int}    runCount    how many times it has run
 * @field {string} lastStarted when it last ran, as reported
 * @field {string} comment     free-text comment, "" when unset
 */
export def struct Script {
    id as string,
    name as string,
    source as string,
    policy as string,
    runCount as int,
    lastStarted as string,
    comment as string
};

/**
 * List the stored scripts.
 *
 * @param {Client} c an open client
 * @return {list of Script} all scripts
 */
export func scripts(c as Client) {
    def rows as list of map of string to string init getAll($c, SCRIPT_PATH);
    def out as list of Script init [];
    for (def row in $rows) {
        $out[] = scriptFromRow($row);
    }
    return $out;
}

/**
 * Look one script up by name.
 *
 * @param {Client} c    an open client
 * @param {string} name the script name
 * @return {Script} the script
 * @throws {Error} kind "routeros" when no script has that name
 */
export func scriptByName(c as Client, name as string) {
    def row as map of string to string init findByName($c, SCRIPT_PATH, $name);
    if (len($row) == 0) {
        raiseError("the script \"" + $name + "\" was not found on the router");
    }
    return scriptFromRow($row);
}

/**
 * Store a named RouterOS script.
 *
 * A stored script is written once and reused: the scheduler and netwatch
 * can run it by name (`scheduleScript(c, name, interval, source)` also
 * takes a stored script's name as its source), and `runScript` triggers
 * it on demand. `source` is RouterOS scripting, not Jennifer. Fails if
 * the name is taken.
 *
 * @param {Client} c       an open client
 * @param {string} name    name for the script
 * @param {string} source  the RouterOS script source
 * @param {string} comment friendly note ("" for none)
 * @return {string} the RouterOS id of the new script
 * @throws {Error} kind "routeros" on a bad name, empty source, or a
 *                 script that already exists
 * @example
 *   mt.addScript($c, "backup-and-mail",
 *       "/system backup save name=nightly; /tool e-mail send to=noc@example.org subject=backup file=nightly.backup");
 *   mt.runScript($c, "backup-and-mail");
 */
export func addScript(c as Client, name as string, source as string, comment as string) {
    ensureName($name, "script");
    if (strings.trim($source) == "") {
        raiseError("the script source must not be empty");
    }
    if (idByName($c, SCRIPT_PATH, $name) != "") {
        raiseError("the script \"" + $name + "\" already exists - use updateScript to change it");
    }
    def attrs as map of string to string init {"name": $name, "source": $source};
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, SCRIPT_PATH, $attrs);
}

/**
 * Replace the source of an existing script.
 *
 * @param {Client} c      an open client
 * @param {string} name   the script name
 * @param {string} source the new RouterOS script source
 * @throws {Error} kind "routeros" on empty source or an unknown script
 */
export func updateScript(c as Client, name as string, source as string) {
    if (strings.trim($source) == "") {
        raiseError("the script source must not be empty");
    }
    set($c, SCRIPT_PATH, requiredId($c, SCRIPT_PATH, $name, "script"), {"source": $source});
}

/**
 * Run a stored script now.
 *
 * It runs on the router with the script's own policies (RouterOS
 * script, not Jennifer) - a typo or a missing permission shows up in
 * the router log at run time, not here.
 *
 * @param {Client} c    an open client
 * @param {string} name the script name
 * @return {string} the script's return value, "" when it returns nothing
 * @throws {Error} kind "routeros" when no script has that name,
 *                 kind "mikrotik" when the script itself errors
 */
export func runScript(c as Client, name as string) {
    return apiRun($c, SCRIPT_PATH + "/run", {".id": requiredId($c, SCRIPT_PATH, $name, "script")});
}

/**
 * Delete a stored script.
 *
 * A scheduler entry that runs it by name will fail once it is gone -
 * remove or repoint the schedule too.
 *
 * @param {Client} c    an open client
 * @param {string} name the script name
 * @throws {Error} kind "routeros" when no script has that name
 */
export func removeScript(c as Client, name as string) {
    remove($c, SCRIPT_PATH, requiredId($c, SCRIPT_PATH, $name, "script"));
}

/**
 * Fold a reply row into a Script.
 *
 * @param {map of string to string} row a "/system/script/print" row
 * @return {Script} the typed script
 * @internal
 */
func scriptFromRow(row as map of string to string) {
    return Script{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        source: rowValue($row, "source"),
        policy: rowValue($row, "policy"),
        runCount: rowInt($row, "run-count"),
        lastStarted: rowValue($row, "last-started"),
        comment: rowValue($row, "comment")
    };
}
