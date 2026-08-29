# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - GRE tunnels: a routed point-to-point link over IP.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the GRE tunnel list. */
export def const GRE_PATH as string init "/interface/gre";

/**
 * One GRE tunnel: a layer-3 point-to-point link carried over IP.
 *
 * Unlike EoIP (layer 2, bridged), a GRE tunnel is ROUTED: give both
 * ends an address in a small shared network and point routes at it.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} name          tunnel interface name (e.g. "grebranch")
 * @field {string} remoteAddress the other router's IP address
 * @field {string} localAddress  our source address, "" for automatic
 * @field {string} mtu           MTU as reported
 * @field {string} keepalive     keepalive setting as reported
 * @field {bool}   running       true when the tunnel is up
 * @field {bool}   disabled      true when the tunnel is switched off
 * @field {string} comment       free-text comment, "" when unset
 */
export def struct GreTunnel {
    id as string,
    name as string,
    remoteAddress as string,
    localAddress as string,
    mtu as string,
    keepalive as string,
    running as bool,
    disabled as bool,
    comment as string
};

/**
 * List every GRE tunnel on the router.
 *
 * @param {Client} c an open client
 * @return {list of GreTunnel} all GRE tunnels
 */
export func greTunnels(c as Client) {
    def rows as list of map of string to string init getAll($c, GRE_PATH);
    def out as list of GreTunnel init [];
    for (def row in $rows) {
        $out[] = greFromRow($row);
    }
    return $out;
}

/**
 * Look one GRE tunnel up by its name.
 *
 * @param {Client} c    an open client
 * @param {string} name the tunnel's name
 * @return {GreTunnel} the tunnel
 * @throws {Error} kind "routeros" when no GRE tunnel has that name
 */
export func greTunnelByName(c as Client, name as string) {
    def row as map of string to string init findByName($c, GRE_PATH, $name);
    if (len($row) == 0) {
        raiseError("the GRE tunnel \"" + $name + "\" was not found on the router");
    }
    return greFromRow($row);
}

/**
 * Create a GRE tunnel to another router.
 *
 * The other end needs the mirror tunnel (your address as its remote).
 * A GRE tunnel is a routed link: give each end an address in a small
 * shared network (a /30 fits exactly two) and add routes through it -
 * the example shows the whole shape. GRE is standard (RFC 2784), so
 * the far end can be any vendor, not just a MikroTik.
 *
 * GRE itself is NOT encrypted - across untrusted paths use
 * `addSecureGreTunnel` or prefer WireGuard outright.
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the tunnel interface (e.g. "grebranch")
 * @param {string} remoteAddress the other router's IP address
 * @return {string} the RouterOS id of the new tunnel
 * @throws {Error} kind "routeros" on a bad name or address, a name
 *                 already taken, or an existing tunnel to that remote
 * @example
 *   mt.addGreTunnel($c, "grebranch", "203.0.113.99");
 *   mt.addIpAddress($c, "10.99.0.1/30", "grebranch");
 *   mt.addRoute($c, "192.168.20.0/24", "10.99.0.2", "branch LAN via GRE");
 *   # the far end mirrors it: remote = our address, 10.99.0.2/30, route back
 */
export func addGreTunnel(c as Client, name as string, remoteAddress as string) {
    return greAdd($c, $name, $remoteAddress, "");
}

/**
 * Create a GRE tunnel encrypted with RouterOS's coupled IPsec.
 *
 * Setting the shared secret makes RouterOS wrap the tunnel in an IPsec
 * transport automatically - the same secret must be configured on the
 * other end. Pick a long random secret; it is the only thing
 * protecting the traffic.
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the tunnel interface
 * @param {string} remoteAddress the other router's IP address
 * @param {string} ipsecSecret   the shared IPsec secret (write-only)
 * @return {string} the RouterOS id of the new tunnel
 * @throws {Error} kind "routeros" on bad input or an empty secret
 */
export func addSecureGreTunnel(
    c as Client,
    name as string,
    remoteAddress as string,
    ipsecSecret as string) {
    if (strings.trim($ipsecSecret) == "") {
        raiseError("the IPsec secret must not be empty - it is the only thing protecting the tunnel");
    }
    return greAdd($c, $name, $remoteAddress, $ipsecSecret);
}

/**
 * Delete a GRE tunnel.
 *
 * Addresses on it disappear with it; routes through it become
 * unreachable - clean those up first for a tidy teardown.
 *
 * @param {Client} c    an open client
 * @param {string} name the tunnel's name
 * @throws {Error} kind "routeros" when no GRE tunnel has that name
 */
export func removeGreTunnel(c as Client, name as string) {
    remove($c, GRE_PATH, requiredId($c, GRE_PATH, $name, "GRE tunnel"));
}

/**
 * Switch a GRE tunnel on.
 *
 * @param {Client} c    an open client
 * @param {string} name the tunnel's name
 * @throws {Error} kind "routeros" when no GRE tunnel has that name
 */
export func enableGreTunnel(c as Client, name as string) {
    enable($c, GRE_PATH, requiredId($c, GRE_PATH, $name, "GRE tunnel"));
}

/**
 * Switch a GRE tunnel off; routes through it lose their link.
 *
 * @param {Client} c    an open client
 * @param {string} name the tunnel's name
 * @throws {Error} kind "routeros" when no GRE tunnel has that name
 */
export func disableGreTunnel(c as Client, name as string) {
    disable($c, GRE_PATH, requiredId($c, GRE_PATH, $name, "GRE tunnel"));
}

/**
 * Validate and create a GRE tunnel; empty secret omits the IPsec
 * coupling.
 *
 * @param {Client} c             an open client
 * @param {string} name          tunnel name
 * @param {string} remoteAddress the far end
 * @param {string} secret        IPsec secret, "" for none
 * @return {string} the RouterOS id of the new tunnel
 * @throws {Error} kind "routeros" on bad input or a clashing tunnel
 * @internal
 */
func greAdd(c as Client, name as string, remoteAddress as string, secret as string) {
    ensureName($name, "GRE tunnel");
    def remote as string init strings.trim($remoteAddress);
    ensureIpAddress($remote);
    if (idByName($c, GRE_PATH, $name) != "") {
        raiseError("the GRE tunnel \"" + $name + "\" already exists");
    }
    def rows as list of map of string to string init getAll($c, GRE_PATH);
    def clash as map of string to string init findRowByField($rows, "remote-address", $remote);
    if (len($clash) > 0) {
        raiseError("a GRE tunnel to " + $remote + " already exists: \"" + rowValue($clash, "name") +
            "\"");
    }
    def attrs as map of string to string init {"name": $name, "remote-address": $remote};
    if ($secret != "") {
        $attrs["ipsec-secret"] = $secret;
    }
    return add($c, GRE_PATH, $attrs);
}

/**
 * Fold a reply row into a GreTunnel.
 *
 * @param {map of string to string} row an "/interface/gre/print" row
 * @return {GreTunnel} the typed tunnel
 * @internal
 */
func greFromRow(row as map of string to string) {
    return GreTunnel{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        remoteAddress: rowValue($row, "remote-address"),
        localAddress: rowValue($row, "local-address"),
        mtu: rowValue($row, "mtu"),
        keepalive: rowValue($row, "keepalive"),
        running: rowBool($row, "running"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
