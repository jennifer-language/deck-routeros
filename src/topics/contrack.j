# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - connection tracking: the live connection table.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the connection-tracking settings. */
export def const CONNTRACK_SETTINGS_PATH as string init "/ip/firewall/connection/tracking";

/** RouterOS API path of the live connection table. */
export def const CONNECTION_PATH as string init "/ip/firewall/connection";

/**
 * The connection-tracking settings.
 *
 * @field {string} enabled      "auto" / "yes" / "no" as reported
 * @field {int}    totalEntries connections tracked right now
 * @field {int}    maxEntries   the table's capacity
 */
export def struct ConntrackSettings {
    enabled as string,
    totalEntries as int,
    maxEntries as int
};

/**
 * One tracked connection.
 *
 * @field {string} id          internal RouterOS id
 * @field {string} protocol    the protocol ("tcp", "udp", ...)
 * @field {string} srcAddress  source address:port
 * @field {string} dstAddress  destination address:port
 * @field {string} tcpState    TCP state ("established", ...), "" for non-TCP
 * @field {string} timeout     time until the entry expires
 * @field {string} connectionMark the connection mark, "" when none
 */
export def struct Connection {
    id as string,
    protocol as string,
    srcAddress as string,
    dstAddress as string,
    tcpState as string,
    timeout as string,
    connectionMark as string
};

/**
 * Read the connection-tracking settings (how full is the table?).
 *
 * @param {Client} c an open client
 * @return {ConntrackSettings} the settings and current fill
 */
export func conntrackSettings(c as Client) {
    return conntrackFromRow(singleRow($c, CONNTRACK_SETTINGS_PATH));
}

/**
 * List the live connection table.
 *
 * Large on a busy router (thousands of rows) - prefer
 * `connectionsFor` to filter. NAT'd connections show their translated
 * form here.
 *
 * @param {Client} c an open client
 * @return {list of Connection} every tracked connection
 */
export func connections(c as Client) {
    def rows as list of map of string to string init getAll($c, CONNECTION_PATH);
    def out as list of Connection init [];
    for (def row in $rows) {
        $out[] = connectionFromRow($row);
    }
    return $out;
}

/**
 * The connections a host is involved in (as source or destination).
 *
 * "What is this device actually talking to" - the fast way to spot a
 * chatty or compromised host. Matching is a substring test, so an
 * address matches whatever port it appears with.
 *
 * @param {Client} c       an open client
 * @param {string} address the host IP to look for
 * @return {list of Connection} the matching connections
 * @throws {Error} kind "routeros" on a malformed address
 */
export func connectionsFor(c as Client, address as string) {
    ensureIpAddress($address);
    def rows as list of map of string to string init getAll($c, CONNECTION_PATH);
    def out as list of Connection init [];
    for (def row in $rows) {
        if (strings.contains(rowValue($row, "src-address"), $address)
                or strings.contains(rowValue($row, "dst-address"), $address)) {
            $out[] = connectionFromRow($row);
        }
    }
    return $out;
}

/**
 * Drop all tracked connections of a host (forces them to re-establish).
 *
 * The precise way to cut off a device without a firewall rule, or to
 * reset connections stuck after a routing change.
 *
 * @param {Client} c       an open client
 * @param {string} address the host IP whose connections to drop
 * @return {int} how many connections were removed
 * @throws {Error} kind "routeros" on a malformed address
 */
export func dropConnectionsFor(c as Client, address as string) {
    ensureIpAddress($address);
    def rows as list of map of string to string init getAll($c, CONNECTION_PATH);
    def dropped as int init 0;
    for (def row in $rows) {
        if (strings.contains(rowValue($row, "src-address"), $address)
                or strings.contains(rowValue($row, "dst-address"), $address)) {
            remove($c, CONNECTION_PATH, rowValue($row, ".id"));
            $dropped = $dropped + 1;
        }
    }
    return $dropped;
}

/**
 * Fold a reply row into the ConntrackSettings.
 *
 * @param {map of string to string} row the tracking-settings row
 * @return {ConntrackSettings} the typed settings
 * @internal
 */
func conntrackFromRow(row as map of string to string) {
    return ConntrackSettings{
        enabled: rowValue($row, "enabled"),
        totalEntries: rowInt($row, "total-entries"),
        maxEntries: rowInt($row, "max-entries")
    };
}

/**
 * Fold a reply row into a Connection.
 *
 * @param {map of string to string} row an "/ip/firewall/connection/print" row
 * @return {Connection} the typed connection
 * @internal
 */
func connectionFromRow(row as map of string to string) {
    return Connection{
        id: rowValue($row, ".id"),
        protocol: rowValue($row, "protocol"),
        srcAddress: rowValue($row, "src-address"),
        dstAddress: rowValue($row, "dst-address"),
        tcpState: rowValue($row, "tcp-state"),
        timeout: rowValue($row, "timeout"),
        connectionMark: rowValue($row, "connection-mark")
    };
}
