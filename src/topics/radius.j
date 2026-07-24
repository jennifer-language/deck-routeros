# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - RADIUS: central authentication for logins, VPN, hotspot.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the RADIUS client list. */
export def const RADIUS_PATH as string init "/radius";

def const RADIUS_SERVICES as list of string init [
    "login", "ppp", "hotspot", "wireless", "dhcp", "ipsec", "dot1x"
];

/**
 * One RADIUS server the router authenticates against.
 *
 * @field {string} id       internal RouterOS id
 * @field {string} address  the RADIUS server's address
 * @field {string} services which subsystems use it, comma-separated
 * @field {string} timeout  the request timeout as reported
 * @field {bool}   disabled true when switched off
 * @field {string} comment  free-text comment, "" when unset
 */
export def struct RadiusServer {
    id as string,
    address as string,
    services as string,
    timeout as string,
    disabled as bool,
    comment as string
};

/**
 * List the configured RADIUS servers.
 *
 * @param {Client} c an open client
 * @return {list of RadiusServer} all servers
 */
export func radiusServers(c as Client) {
    def rows as list of map of string to string init getAll($c, RADIUS_PATH);
    def out as list of RadiusServer init [];
    for (def row in $rows) {
        $out[] = radiusServerFromRow($row);
    }
    return $out;
}

/**
 * Point one or more subsystems at a RADIUS server.
 *
 * Centralizes authentication: instead of local `/user` accounts or PPP
 * secrets, logins are checked against the RADIUS server - the usual
 * back end for a large VPN (`ppp`, `ipsec`), a hotspot, or admin
 * `login`. The shared secret authenticates the router TO the server.
 * Idempotent by address.
 *
 * @param {Client} c        an open client
 * @param {string} address  the RADIUS server's address
 * @param {string} secret   the shared secret (write-only)
 * @param {string} services which subsystems use it, comma-separated:
 *                          login, ppp, hotspot, wireless, dhcp, ipsec, dot1x
 * @param {string} comment  friendly note ("" for none)
 * @return {string} the RouterOS id of the (new or existing) server
 * @throws {Error} kind "routeros" on a bad address, empty secret, or
 *                 unknown service
 * @example
 *   mt.addRadiusServer($c, "10.0.9.20", "a shared secret", "login,ppp", "AD");
 */
export func addRadiusServer(c as Client, address as string, secret as string, services as string, comment as string) {
    def server as string init strings.trim($address);
    ensureIpAddress($server);
    if (strings.trim($secret) == "") {
        raiseError("the RADIUS shared secret must not be empty");
    }
    def svc as string init normalizedRadiusServices($services);
    def rows as list of map of string to string init getAll($c, RADIUS_PATH);
    def existing as map of string to string init findRowByField($rows, "address", $server);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    def attrs as map of string to string init
        {"address": $server, "secret": $secret, "service": $svc};
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, RADIUS_PATH, $attrs);
}

/**
 * Remove a RADIUS server.
 *
 * @param {Client} c       an open client
 * @param {string} address the server's address
 * @throws {Error} kind "routeros" when no such server exists
 */
export func removeRadiusServer(c as Client, address as string) {
    def rows as list of map of string to string init getAll($c, RADIUS_PATH);
    def row as map of string to string init findRowByField($rows, "address", strings.trim($address));
    if (len($row) == 0) {
        raiseError("no RADIUS server at \"" + $address + "\" was found");
    }
    remove($c, RADIUS_PATH, rowValue($row, ".id"));
}

/**
 * Validate and normalize a RADIUS service list.
 *
 * @param {string} csv the candidate list
 * @return {string} the normalized list
 * @throws {Error} kind "routeros" on an empty list or an unknown service
 * @internal
 */
func normalizedRadiusServices(csv as string) {
    def parts as list of string init strings.split($csv, ",");
    def out as list of string init [];
    for (def part in $parts) {
        def p as string init strings.trim($part);
        if ($p == "") {
            raiseError("the service list \"" + $csv + "\" must not contain empty entries");
        }
        if (not lists.contains(RADIUS_SERVICES, $p)) {
            raiseError("unknown RADIUS service \"" + $p + "\" - use one of: " + strings.join(RADIUS_SERVICES, ", "));
        }
        $out[] = $p;
    }
    if (len($out) == 0) {
        raiseError("the service list must name at least one service");
    }
    return strings.join($out, ",");
}

/**
 * Fold a reply row into a RadiusServer.
 *
 * @param {map of string to string} row a "/radius/print" row
 * @return {RadiusServer} the typed server
 * @internal
 */
func radiusServerFromRow(row as map of string to string) {
    return RadiusServer{
        id: rowValue($row, ".id"),
        address: rowValue($row, "address"),
        services: rowValue($row, "service"),
        timeout: rowValue($row, "timeout"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
