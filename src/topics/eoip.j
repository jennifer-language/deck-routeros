# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - EoIP tunnels: a layer-2 wire between two MikroTiks.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the EoIP tunnel list. */
export def const EOIP_PATH as string init "/interface/eoip";

/**
 * One EoIP tunnel: an ethernet link carried over any IP path.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} name          tunnel interface name (e.g. "eoipbranch")
 * @field {string} remoteAddress the other MikroTik's IP address
 * @field {string} localAddress  our source address, "" for automatic
 * @field {int}    tunnelId      the tunnel id - both ends must use the same
 * @field {string} mac           the tunnel's MAC address
 * @field {string} mtu           MTU as reported
 * @field {string} keepalive     keepalive setting as reported
 * @field {bool}   running       true when the tunnel is up
 * @field {bool}   disabled      true when the tunnel is switched off
 * @field {string} comment       free-text comment, "" when unset
 */
export def struct EoipTunnel {
    id as string,
    name as string,
    remoteAddress as string,
    localAddress as string,
    tunnelId as int,
    mac as string,
    mtu as string,
    keepalive as string,
    running as bool,
    disabled as bool,
    comment as string
};

/**
 * List every EoIP tunnel on the router.
 *
 * @param {Client} c an open client
 * @return {list of EoipTunnel} all EoIP tunnels
 */
export func eoipTunnels(c as Client) {
    def rows as list of map of string to string init getAll($c, EOIP_PATH);
    def out as list of EoipTunnel init [];
    for (def row in $rows) {
        $out[] = eoipFromRow($row);
    }
    return $out;
}

/**
 * Look one EoIP tunnel up by its name.
 *
 * @param {Client} c    an open client
 * @param {string} name the tunnel's name
 * @return {EoipTunnel} the tunnel
 * @throws {Error} kind "routeros" when no EoIP tunnel has that name
 */
export func eoipTunnelByName(c as Client, name as string) {
    def row as map of string to string init findByName($c, EOIP_PATH, $name);
    if (len($row) == 0) {
        raiseError("the EoIP tunnel \"" + $name + "\" was not found on the router");
    }
    return eoipFromRow($row);
}

/**
 * Create an EoIP tunnel to another MikroTik.
 *
 * EoIP carries ETHERNET over IP: bridge the tunnel on both ends and
 * the two sites share one LAN (same broadcast domain), across any IP
 * path that connects the routers. The OTHER end needs the mirror
 * tunnel: your address as its remote, and the SAME tunnel id.
 *
 * EoIP itself is NOT encrypted - anyone on the path can read the
 * frames. Across the internet, use `addSecureEoipTunnel` or run the
 * tunnel over WireGuard (remote = the peer's VPN address).
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the tunnel interface (e.g. "eoipbranch")
 * @param {string} remoteAddress the other router's IP address
 * @param {int}    tunnelId      shared id, 0-65535 - both ends must match
 * @return {string} the RouterOS id of the new tunnel
 * @throws {Error} kind "routeros" on a bad name, address, or id, a name
 *                 already taken, or a same-remote/same-id tunnel that
 *                 already exists
 * @example
 *   # site A (10.100.0.1 via WireGuard):
 *   mt.addEoipTunnel($c, "eoipbranch", "10.100.0.2", 7);
 *   mt.addBridgePort($c, "brlan", "eoipbranch");
 *   # site B mirrors it with remote 10.100.0.1 and the same id 7
 */
export func addEoipTunnel(c as Client, name as string, remoteAddress as string, tunnelId as int) {
    return eoipAdd($c, $name, $remoteAddress, $tunnelId, "");
}

/**
 * Create an EoIP tunnel encrypted with RouterOS's coupled IPsec.
 *
 * Setting the shared secret makes RouterOS build an IPsec transport
 * around the tunnel automatically - the same secret must be configured
 * on the other end. Pick a long random secret; it is the only thing
 * protecting the traffic.
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the tunnel interface
 * @param {string} remoteAddress the other router's IP address
 * @param {int}    tunnelId      shared id, 0-65535 - both ends must match
 * @param {string} ipsecSecret   the shared IPsec secret (write-only)
 * @return {string} the RouterOS id of the new tunnel
 * @throws {Error} kind "routeros" on bad input or an empty secret
 */
export func addSecureEoipTunnel(c as Client, name as string, remoteAddress as string, tunnelId as int, ipsecSecret as string) {
    if (strings.trim($ipsecSecret) == "") {
        raiseError("the IPsec secret must not be empty - it is the only thing protecting the tunnel");
    }
    return eoipAdd($c, $name, $remoteAddress, $tunnelId, $ipsecSecret);
}

/**
 * Delete an EoIP tunnel.
 *
 * Anything referencing the tunnel (a bridge port) loses its interface -
 * detach it first for a clean teardown.
 *
 * @param {Client} c    an open client
 * @param {string} name the tunnel's name
 * @throws {Error} kind "routeros" when no EoIP tunnel has that name
 */
export func removeEoipTunnel(c as Client, name as string) {
    remove($c, EOIP_PATH, requiredId($c, EOIP_PATH, $name, "EoIP tunnel"));
}

/**
 * Switch an EoIP tunnel on.
 *
 * @param {Client} c    an open client
 * @param {string} name the tunnel's name
 * @throws {Error} kind "routeros" when no EoIP tunnel has that name
 */
export func enableEoipTunnel(c as Client, name as string) {
    enable($c, EOIP_PATH, requiredId($c, EOIP_PATH, $name, "EoIP tunnel"));
}

/**
 * Switch an EoIP tunnel off; the layer-2 link between the sites drops.
 *
 * @param {Client} c    an open client
 * @param {string} name the tunnel's name
 * @throws {Error} kind "routeros" when no EoIP tunnel has that name
 */
export func disableEoipTunnel(c as Client, name as string) {
    disable($c, EOIP_PATH, requiredId($c, EOIP_PATH, $name, "EoIP tunnel"));
}

/**
 * Validate and create an EoIP tunnel; empty secret omits the IPsec
 * coupling.
 *
 * @param {Client} c             an open client
 * @param {string} name          tunnel name
 * @param {string} remoteAddress the far end
 * @param {int}    tunnelId      shared id
 * @param {string} secret        IPsec secret, "" for none
 * @return {string} the RouterOS id of the new tunnel
 * @throws {Error} kind "routeros" on bad input or a clashing tunnel
 * @internal
 */
func eoipAdd(c as Client, name as string, remoteAddress as string, tunnelId as int, secret as string) {
    ensureName($name, "EoIP tunnel");
    def remote as string init strings.trim($remoteAddress);
    ensureIpAddress($remote);
    ensureTunnelId($tunnelId);
    if (idByName($c, EOIP_PATH, $name) != "") {
        raiseError("the EoIP tunnel \"" + $name + "\" already exists");
    }
    def rows as list of map of string to string init getAll($c, EOIP_PATH);
    def clash as map of string to string init findEoipRow($rows, $remote, $tunnelId);
    if (len($clash) > 0) {
        raiseError("tunnel id " + convert.toString($tunnelId) + " to " + $remote
            + " is already used by \"" + rowValue($clash, "name") + "\"");
    }
    def attrs as map of string to string init {
        "name": $name,
        "remote-address": $remote,
        "tunnel-id": convert.toString($tunnelId)
    };
    if ($secret != "") {
        $attrs["ipsec-secret"] = $secret;
    }
    return add($c, EOIP_PATH, $attrs);
}

/**
 * Validate an EoIP tunnel id.
 *
 * @param {int} tunnelId the candidate id
 * @throws {Error} kind "routeros" when outside 0-65535
 * @internal
 */
func ensureTunnelId(tunnelId as int) {
    if ($tunnelId < 0 or $tunnelId > 65535) {
        raiseError("the tunnel id must be between 0 and 65535 (and match the other end)");
    }
}

/**
 * Find an existing tunnel to a remote with a tunnel id.
 *
 * @param {list of map of string to string} rows "/interface/eoip/print" rows
 * @param {string} remote   the remote address
 * @param {int}    tunnelId the tunnel id
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func findEoipRow(rows as list of map of string to string, remote as string, tunnelId as int) {
    for (def row in $rows) {
        if (rowValue($row, "remote-address") == $remote and rowInt($row, "tunnel-id") == $tunnelId) {
            return $row;
        }
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Fold a reply row into an EoipTunnel.
 *
 * @param {map of string to string} row an "/interface/eoip/print" row
 * @return {EoipTunnel} the typed tunnel
 * @internal
 */
func eoipFromRow(row as map of string to string) {
    return EoipTunnel{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        remoteAddress: rowValue($row, "remote-address"),
        localAddress: rowValue($row, "local-address"),
        tunnelId: rowInt($row, "tunnel-id"),
        mac: rowValue($row, "mac-address"),
        mtu: rowValue($row, "mtu"),
        keepalive: rowValue($row, "keepalive"),
        running: rowBool($row, "running"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
