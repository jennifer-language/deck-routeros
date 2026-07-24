# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - management services: the ways into the router.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the management service list. */
export def const SERVICE_PATH as string init "/ip/service";

def const KNOWN_SERVICES as list of string init [
    "api", "api-ssl", "ftp", "ssh", "telnet", "winbox", "www", "www-ssl"
];

/**
 * One management service: a way to log into the router.
 *
 * The list is fixed - services are enabled, disabled, and restricted,
 * never added or removed.
 *
 * @field {string} id          internal RouterOS id
 * @field {string} name        service name ("api", "ssh", "winbox", ...)
 * @field {int}    port        TCP port it listens on
 * @field {string} address     networks allowed to connect, "" for anywhere
 * @field {string} certificate TLS certificate name (ssl services), "" otherwise
 * @field {bool}   invalid     true when misconfigured (e.g. ssl without a
 *                             certificate) - the service does not actually run
 * @field {bool}   disabled    true when the service is switched off
 */
export def struct Service {
    id as string,
    name as string,
    port as int,
    address as string,
    certificate as string,
    invalid as bool,
    disabled as bool
};

/**
 * List the management services and their state.
 *
 * The security audit in one call: anything enabled, unrestricted, and
 * cleartext (telnet, ftp, www) deserves a hard look.
 *
 * @param {Client} c an open client
 * @return {list of Service} all services
 */
export func services(c as Client) {
    def rows as list of map of string to string init getAll($c, SERVICE_PATH);
    def out as list of Service init [];
    for (def row in $rows) {
        $out[] = serviceFromRow($row);
    }
    return $out;
}

/**
 * Look one management service up by its name.
 *
 * @param {Client} c    an open client
 * @param {string} name "api", "api-ssl", "ftp", "ssh", "telnet",
 *                      "winbox", "www", or "www-ssl"
 * @return {Service} the service
 * @throws {Error} kind "routeros" on an unknown service name
 */
export func serviceByName(c as Client, name as string) {
    ensureServiceName($name);
    def row as map of string to string init findByName($c, SERVICE_PATH, $name);
    if (len($row) == 0) {
        raiseError("the service \"" + $name + "\" was not found on the router");
    }
    return serviceFromRow($row);
}

/**
 * Switch a management service on.
 *
 * @param {Client} c    an open client
 * @param {string} name the service name
 * @throws {Error} kind "routeros" on an unknown service name
 */
export func enableService(c as Client, name as string) {
    ensureServiceName($name);
    enable($c, SERVICE_PATH, requiredId($c, SERVICE_PATH, $name, "service"));
}

/**
 * Switch a management service off.
 *
 * CAUTION: disabling the service this session came in through ("api"
 * or "api-ssl") disconnects you and closes that door behind you. To
 * turn plain "api" off, do it from an api-ssl session - and always
 * keep at least one working way in (winbox or ssh) before closing
 * doors.
 *
 * @param {Client} c    an open client
 * @param {string} name the service name
 * @throws {Error} kind "routeros" on an unknown service name
 */
export func disableService(c as Client, name as string) {
    ensureServiceName($name);
    disable($c, SERVICE_PATH, requiredId($c, SERVICE_PATH, $name, "service"));
}

/**
 * Move a management service to another TCP port.
 *
 * A non-default SSH or WinBox port cuts scanner noise dramatically -
 * it is obscurity, not security, so combine it with `restrictService`.
 * A port already used by another service is refused with that service
 * named.
 *
 * @param {Client} c    an open client
 * @param {string} name the service name
 * @param {int}    port the new port, 1-65535
 * @throws {Error} kind "routeros" on an unknown service, a bad port,
 *                 or a port another service already uses
 */
export func setServicePort(c as Client, name as string, port as int) {
    ensureServiceName($name);
    ensurePort($port);
    def rows as list of map of string to string init getAll($c, SERVICE_PATH);
    def owner as string init serviceUsingPort($rows, $port, $name);
    if ($owner != "") {
        raiseError("port " + convert.toString($port) + " is already used by the service \"" + $owner + "\"");
    }
    set($c, SERVICE_PATH, requiredId($c, SERVICE_PATH, $name, "service"),
        {"port": convert.toString($port)});
}

/**
 * Limit where a management service accepts connections from.
 *
 * The single most effective hardening step: management reachable only
 * from the management networks. Applies to NEW connections - but make
 * very sure your own network is in the list before restricting the
 * API service you are using. Pass "" to lift the restriction.
 *
 * @param {Client} c         an open client
 * @param {string} name      the service name
 * @param {string} addresses allowed sources: IPs and/or CIDR networks,
 *                           comma-separated (e.g. "10.0.9.0/24"); "" = anywhere
 * @throws {Error} kind "routeros" on an unknown service or malformed address
 * @example
 *   mt.restrictService($c, "winbox", "10.0.9.0/24");
 *   mt.restrictService($c, "ssh", "10.0.9.0/24");
 */
export func restrictService(c as Client, name as string, addresses as string) {
    ensureServiceName($name);
    def allowed as string init "";
    if (strings.trim($addresses) != "") {
        $allowed = normalizedUserAddress($addresses);
    }
    set($c, SERVICE_PATH, requiredId($c, SERVICE_PATH, $name, "service"),
        {"address": $allowed});
}

/**
 * Switch the cleartext relics off: telnet and ftp.
 *
 * Both send passwords unencrypted and have modern replacements (ssh,
 * sftp/scp over ssh). Neither can carry this API session, so this is
 * always safe to call. Plain "www" and "api" are also cleartext but
 * may be in legitimate LAN use - decide about those consciously
 * (`disableService`).
 *
 * @param {Client} c an open client
 * @return {int} how many services were switched off (already-disabled
 *               ones are skipped)
 */
export func disableInsecureServices(c as Client) {
    def rows as list of map of string to string init getAll($c, SERVICE_PATH);
    def count as int init 0;
    for (def row in $rows) {
        def name as string init rowValue($row, "name");
        if (($name == "telnet" or $name == "ftp") and not rowBool($row, "disabled")) {
            disable($c, SERVICE_PATH, rowValue($row, ".id"));
            $count = $count + 1;
        }
    }
    return $count;
}

/**
 * Validate a management service name.
 *
 * @param {string} name the candidate
 * @throws {Error} kind "routeros" on an unknown service
 * @internal
 */
func ensureServiceName(name as string) {
    if (not lists.contains(KNOWN_SERVICES, $name)) {
        raiseError("unknown service \"" + $name + "\" - use one of: " + strings.join(KNOWN_SERVICES, ", "));
    }
}

/**
 * Which service (other than `ownName`) already listens on a port?
 *
 * @param {list of map of string to string} rows "/ip/service/print" rows
 * @param {int}    port    the port to check
 * @param {string} ownName service whose own port does not count
 * @return {string} the owning service's name, or "" when the port is free
 * @internal
 */
func serviceUsingPort(rows as list of map of string to string, port as int, ownName as string) {
    for (def row in $rows) {
        if (rowInt($row, "port") == $port and rowValue($row, "name") != $ownName) {
            return rowValue($row, "name");
        }
    }
    return "";
}

/**
 * Fold a reply row into a Service.
 *
 * @param {map of string to string} row an "/ip/service/print" row
 * @return {Service} the typed service
 * @internal
 */
func serviceFromRow(row as map of string to string) {
    return Service{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        port: rowInt($row, "port"),
        address: rowValue($row, "address"),
        certificate: rowValue($row, "certificate"),
        invalid: rowBool($row, "invalid"),
        disabled: rowBool($row, "disabled")
    };
}
