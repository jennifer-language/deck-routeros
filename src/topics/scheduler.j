# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - scheduled scripts.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the scheduler (scripts on a timer). */
export def const SCHEDULER_PATH as string init "/system/scheduler";

/**
 * One scheduler entry: a script the router runs on a timer.
 *
 * @field {string} id        internal RouterOS id
 * @field {string} name      task name
 * @field {string} startTime when the timer starts ("HH:MM:SS" or "startup")
 * @field {string} startDate first day the timer is armed, as reported
 * @field {string} interval  time between runs ("1d", "00:30:00"; "0" = run once)
 * @field {string} onEvent   what runs: RouterOS script source, or the name
 *                           of a "/system/script"
 * @field {string} nextRun   when the task fires next, as reported
 * @field {int}    runCount  how often the task has run so far
 * @field {bool}   disabled  true when the task is switched off
 * @field {string} comment   free-text comment, "" when unset
 */
export def struct ScheduledTask {
    id as string,
    name as string,
    startTime as string,
    startDate as string,
    interval as string,
    onEvent as string,
    nextRun as string,
    runCount as int,
    disabled as bool,
    comment as string
};

/**
 * List every scheduled task on the router.
 *
 * @param {Client} c an open client
 * @return {list of ScheduledTask} all scheduler entries
 */
export func scheduledTasks(c as Client) {
    def rows as list of map of string to string init getAll($c, SCHEDULER_PATH);
    def out as list of ScheduledTask init [];
    for (def row in $rows) {
        $out[] = scheduledTaskFromRow($row);
    }
    return $out;
}

/**
 * Run a RouterOS script repeatedly, every `interval`.
 *
 * `source` is RouterOS scripting (the language of the router's console,
 * e.g. "/system backup save name=nightly"), or simply the name of an
 * existing "/system/script". The script runs with the rights of the
 * user this client is logged in as.
 *
 * @param {Client} c        an open client
 * @param {string} name     name for the task; the handle for the other calls
 * @param {string} interval time between runs: "30s", "10m", "2h", "1d",
 *                          "1w", combined "1d12h", or "HH:MM:SS"
 * @param {string} source   what to run (RouterOS script source or script name)
 * @return {string} the RouterOS id of the new task
 * @throws {Error} kind "routeros" on a bad name, interval, or empty source
 * @example
 *   mt.scheduleScript($c, "reboot-nightly", "1d", "/system reboot");
 */
export func scheduleScript(c as Client, name as string, interval as string, source as string) {
    ensureName($name, "task");
    def every as string init strings.trim($interval);
    ensureSchedulerInterval($every);
    ensureScriptSource($source);
    return add($c, SCHEDULER_PATH, {"name": $name, "interval": $every, "on-event": $source});
}

/**
 * Run a RouterOS script once a day at a fixed time.
 *
 * @param {Client} c         an open client
 * @param {string} name      name for the task
 * @param {string} startTime the daily time, "HH:MM:SS" (router-local,
 *                           e.g. "03:00:00")
 * @param {string} source    what to run (RouterOS script source or script name)
 * @return {string} the RouterOS id of the new task
 * @throws {Error} kind "routeros" on a bad name, time, or empty source
 * @example
 *   mt.scheduleDaily($c, "nightly-backup", "03:00:00", "/system backup save name=nightly");
 */
export func scheduleDaily(c as Client, name as string, startTime as string, source as string) {
    ensureName($name, "task");
    def at as string init strings.trim($startTime);
    ensureClockTime($at);
    ensureScriptSource($source);
    return add(
        $c,
        SCHEDULER_PATH,
        {"name": $name, "start-time": $at, "interval": "1d", "on-event": $source});
}

/**
 * Run a RouterOS script once at every boot.
 *
 * @param {Client} c      an open client
 * @param {string} name   name for the task
 * @param {string} source what to run (RouterOS script source or script name)
 * @return {string} the RouterOS id of the new task
 * @throws {Error} kind "routeros" on a bad name or empty source
 */
export func scheduleAtStartup(c as Client, name as string, source as string) {
    ensureName($name, "task");
    ensureScriptSource($source);
    return add(
        $c,
        SCHEDULER_PATH,
        {"name": $name, "start-time": "startup", "interval": "0", "on-event": $source});
}

/**
 * Delete a scheduled task by name.
 *
 * @param {Client} c    an open client
 * @param {string} name the task's name
 * @throws {Error} kind "routeros" when no task has that name
 */
export func removeScheduledTask(c as Client, name as string) {
    remove($c, SCHEDULER_PATH, requiredId($c, SCHEDULER_PATH, $name, "scheduled task"));
}

/**
 * Switch a scheduled task on.
 *
 * @param {Client} c    an open client
 * @param {string} name the task's name
 * @throws {Error} kind "routeros" when no task has that name
 */
export func enableScheduledTask(c as Client, name as string) {
    enable($c, SCHEDULER_PATH, requiredId($c, SCHEDULER_PATH, $name, "scheduled task"));
}

/**
 * Switch a scheduled task off; it stays configured but stops firing.
 *
 * @param {Client} c    an open client
 * @param {string} name the task's name
 * @throws {Error} kind "routeros" when no task has that name
 */
export func disableScheduledTask(c as Client, name as string) {
    disable($c, SCHEDULER_PATH, requiredId($c, SCHEDULER_PATH, $name, "scheduled task"));
}

/**
 * Validate one clock component: all digits, within 0..max.
 *
 * @param {string} part the component (e.g. "03")
 * @param {int}    max  23 for hours, 59 for minutes/seconds
 * @throws {Error} kind "routeros" on a non-digit or out-of-range part
 * @internal
 */
func clockPart(part as string, max as int) {
    if (len($part) < 1 or len($part) > 2) {
        raiseError("a time must be written like \"03:00:00\" (HH:MM:SS)");
    }
    def chars as list of string init strings.chars($part);
    for (def ch in $chars) {
        if (not strings.contains(DIGIT_CHARS, $ch)) {
            raiseError("a time must be written like \"03:00:00\" (HH:MM:SS)");
        }
    }
    if (convert.toInt($part) > $max) {
        raiseError("the time component \"" + $part + "\" is out of range");
    }
}

/**
 * Validate a wall-clock time "HH:MM:SS".
 *
 * @param {string} value the candidate (already trimmed)
 * @throws {Error} kind "routeros" on any other shape
 * @internal
 */
func ensureClockTime(value as string) {
    def parts as list of string init strings.split($value, ":");
    if (len($parts) != 3) {
        raiseError("\"" + $value + "\" is not a time - write it like \"03:00:00\" (HH:MM:SS)");
    }
    clockPart($parts[0], 23);
    clockPart($parts[1], 59);
    clockPart($parts[2], 59);
}

/**
 * Validate a scheduler interval.
 *
 * Accepts "HH:MM:SS", or duration tokens: digits followed by one of
 * s / m / h / d / w, combined freely ("30s", "1d", "1d12h"); trailing
 * bare digits count as seconds ("90"). "0" (run once) is valid.
 *
 * @param {string} value the candidate (already trimmed)
 * @throws {Error} kind "routeros" on any other shape
 * @internal
 */
func ensureSchedulerInterval(value as string) {
    if ($value == "") {
        raiseError("the interval must not be empty - write it like \"10m\", \"1d\", or \"00:30:00\"");
    }
    if (strings.contains($value, ":")) {
        ensureClockTime($value);
        return;
    }
    def sawDigit as bool init false;
    def pending as bool init false;
    def chars as list of string init strings.chars($value);
    for (def ch in $chars) {
        if (strings.contains(DIGIT_CHARS, $ch)) {
            $sawDigit = true;
            $pending = true;
        } elseif (strings.contains("smhdw", $ch)) {
            if (not $pending) {
                raiseError("\"" + $value +
                    "\" is not an interval - write it like \"10m\", \"1d\", or \"1d12h\"");
            }
            $pending = false;
        } else {
            raiseError("\"" + $value +
                "\" is not an interval - write it like \"10m\", \"1d\", or \"1d12h\"");
        }
    }
    if (not $sawDigit) {
        raiseError("\"" + $value +
            "\" is not an interval - write it like \"10m\", \"1d\", or \"1d12h\"");
    }
}

/**
 * Validate a scheduler script source: something must actually run.
 *
 * @param {string} source the candidate on-event content
 * @throws {Error} kind "routeros" when empty
 * @internal
 */
func ensureScriptSource(source as string) {
    if (strings.trim($source) == "") {
        raiseError("the script source must not be empty - RouterOS script lines or the name of a /system/script");
    }
}

/**
 * Fold a reply row into a ScheduledTask.
 *
 * @param {map of string to string} row a "/system/scheduler/print" row
 * @return {ScheduledTask} the typed task
 * @internal
 */
func scheduledTaskFromRow(row as map of string to string) {
    return ScheduledTask{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        startTime: rowValue($row, "start-time"),
        startDate: rowValue($row, "start-date"),
        interval: rowValue($row, "interval"),
        onEvent: rowValue($row, "on-event"),
        nextRun: rowValue($row, "next-run"),
        runCount: rowInt($row, "run-count"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
