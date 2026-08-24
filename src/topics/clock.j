# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - clock and NTP: a router that knows what time it is.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the system clock menu. */
export def const CLOCK_PATH as string init "/system/clock";

/** RouterOS API path of the NTP client menu (RouterOS v7 shape). */
export def const NTP_CLIENT_PATH as string init "/system/ntp/client";

/**
 * The router's clock state.
 *
 * @field {string} time       current time as reported
 * @field {string} date       current date as reported
 * @field {string} timezone   timezone name (e.g. "Europe/Berlin")
 * @field {bool}   autodetect true when the router guesses the timezone
 * @field {string} gmtOffset  the resulting UTC offset as reported
 */
export def struct Clock {
    time as string,
    date as string,
    timezone as string,
    autodetect as bool,
    gmtOffset as string
};

/**
 * The NTP client state.
 *
 * @field {bool}   enabled true when the router syncs its clock
 * @field {string} servers the configured NTP servers, comma-separated
 * @field {string} status  the sync state as reported
 * @field {bool}   synced  computed: the status equals "synchronized"
 */
export def struct NtpStatus {
    enabled as bool,
    servers as string,
    status as string,
    synced as bool
};

/**
 * Read the router's clock.
 *
 * Certificate validation, scheduler times, and log timestamps all
 * depend on it - check this first when any of those act strangely.
 *
 * @param {Client} c an open client
 * @return {Clock} the clock state
 */
export func clock(c as Client) {
    return clockFromRow(singleRow($c, CLOCK_PATH));
}

/**
 * Set the router's timezone.
 *
 * @param {Client} c        an open client
 * @param {string} timezone an IANA name like "Europe/Berlin", or "UTC"
 * @throws {Error} kind "routeros" on an empty or spaced name,
 *                 kind "mikrotik" when the router does not know the zone
 */
export func setTimezone(c as Client, timezone as string) {
    def tz as string init strings.trim($timezone);
    ensureName($tz, "timezone");
    apiRun($c, CLOCK_PATH + "/set",
        {"time-zone-name": $tz, "time-zone-autodetect": "no"});
}

/**
 * Keep the clock right automatically: enable the NTP client.
 *
 * MikroTiks have no battery clock - without NTP the time restarts at
 * boot and certificates, schedules, and logs drift into fiction.
 *
 * @param {Client} c       an open client
 * @param {string} servers NTP servers, comma-separated - DNS names or
 *                         IPs (e.g. "pool.ntp.org" or "192.168.88.1")
 * @throws {Error} kind "routeros" on an empty or malformed server list
 * @example
 *   mt.useNtp($c, "pool.ntp.org");
 *   mt.setTimezone($c, "Europe/Berlin");
 */
export func useNtp(c as Client, servers as string) {
    def serverList as string init normalizedNtpServers($servers);
    apiRun($c, NTP_CLIENT_PATH + "/set",
        {"enabled": "yes", "servers": $serverList});
}

/**
 * Switch the NTP client off; the clock free-runs (and resets at boot).
 *
 * @param {Client} c an open client
 */
export func disableNtp(c as Client) {
    apiRun($c, NTP_CLIENT_PATH + "/set", {"enabled": "no"});
}

/**
 * Read the NTP client state; `synced` is the health flag.
 *
 * @param {Client} c an open client
 * @return {NtpStatus} the NTP state
 */
export func ntpStatus(c as Client) {
    return ntpFromRow(singleRow($c, NTP_CLIENT_PATH));
}

/**
 * Validate and normalize a comma-separated NTP server list (DNS names
 * or IPs, spaces tolerated).
 *
 * @param {string} csv the candidate list
 * @return {string} the normalized list
 * @throws {Error} kind "routeros" on an empty list or a spaced entry
 * @internal
 */
func normalizedNtpServers(csv as string) {
    def parts as list of string init strings.split($csv, ",");
    def out as list of string init [];
    for (def part in $parts) {
        def p as string init strings.trim($part);
        if ($p == "") {
            raiseError("the NTP server list \"" + $csv + "\" must not contain empty entries");
        }
        ensureHost($p);
        $out[] = $p;
    }
    if (len($out) == 0) {
        raiseError("the NTP server list must contain at least one server");
    }
    return strings.join($out, ",");
}

/**
 * Fold a reply row into the Clock.
 *
 * @param {map of string to string} row the "/system/clock/print" row
 * @return {Clock} the typed clock state
 * @internal
 */
func clockFromRow(row as map of string to string) {
    return Clock{
        time: rowValue($row, "time"),
        date: rowValue($row, "date"),
        timezone: rowValue($row, "time-zone-name"),
        autodetect: rowBool($row, "time-zone-autodetect"),
        gmtOffset: rowValue($row, "gmt-offset")
    };
}

/**
 * Fold a reply row into the NtpStatus.
 *
 * `synced` is computed here: the status equals "synchronized".
 *
 * @param {map of string to string} row the "/system/ntp/client/print" row
 * @return {NtpStatus} the typed NTP state
 * @internal
 */
func ntpFromRow(row as map of string to string) {
    def status as string init rowValue($row, "status");
    return NtpStatus{
        enabled: rowBool($row, "enabled"),
        servers: rowValue($row, "servers"),
        status: $status,
        synced: $status == "synchronized"
    };
}
