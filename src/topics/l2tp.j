# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - L2TP: the works-on-every-device remote-access VPN.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the L2TP server settings (single row). */
export def const L2TP_SERVER_PATH as string init "/interface/l2tp-server/server";

/** RouterOS API path of the L2TP client list (dial OUT to a server). */
export def const L2TP_CLIENT_PATH as string init "/interface/l2tp-client";

/**
 * The L2TP server settings.
 *
 * @field {bool}   enabled        true when the server accepts connections
 * @field {bool}   useIpsec       true when L2TP/IPsec (encrypted) is required
 * @field {string} defaultProfile the PPP profile applied to logins
 */
export def struct L2tpServer {
    enabled as bool,
    useIpsec as bool,
    defaultProfile as string
};

/**
 * One L2TP client (this router dialing out to an L2TP server).
 *
 * @field {string} id            internal RouterOS id
 * @field {string} name          the client interface name
 * @field {string} connectTo     the server address
 * @field {string} user          the login on the server
 * @field {bool}   running       true when the tunnel is up
 * @field {bool}   disabled      true when switched off
 * @field {string} comment       free-text comment, "" when unset
 */
export def struct L2tpClient {
    id as string,
    name as string,
    connectTo as string,
    user as string,
    running as bool,
    disabled as bool,
    comment as string
};

/**
 * Read the L2TP server settings.
 *
 * @param {Client} c an open client
 * @return {L2tpServer} the server state
 */
export func l2tpServerStatus(c as Client) {
    return l2tpServerFromRow(singleRow($c, L2TP_SERVER_PATH));
}

/**
 * Turn on an L2TP/IPsec remote-access VPN server.
 *
 * The remote-access VPN that needs no client software: Windows, macOS,
 * iOS, and Android all dial L2TP/IPsec natively. Enables the server,
 * requires IPsec encryption with the given pre-shared key (plain L2TP
 * is cleartext - never enable it without this), and opens the firewall
 * for L2TP (udp/1701), IKE (udp/500), NAT-T (udp/4500), and ESP. Add
 * logins with `addVpnUser`. Idempotent.
 *
 * @param {Client} c           an open client
 * @param {string} ipsecSecret the shared secret every client also enters
 * @throws {Error} kind "routeros" on an empty secret
 * @example
 *   mt.enableL2tpServer($c, "a long random ipsec secret");
 *   mt.addVpnUser($c, "alice", "her password", "l2tp", "field laptop");
 *   # clients set: server = the router's public address/name, PSK = the
 *   # secret, username/password = the login
 */
export func enableL2tpServer(c as Client, ipsecSecret as string) {
    if (strings.trim($ipsecSecret) == "") {
        raiseError("the IPsec secret must not be empty - L2TP without it is cleartext");
    }
    mikrotik.run($c.session, L2TP_SERVER_PATH + "/set",
        {"enabled": "yes", "use-ipsec": "required", "ipsec-secret": $ipsecSecret});
    ensureInputAccept($c, "l2tp: server (l2tp)", {"protocol": "udp", "dst-port": "1701"});
    ensureInputAccept($c, "l2tp: server (ike)", {"protocol": "udp", "dst-port": "500"});
    ensureInputAccept($c, "l2tp: server (nat-t)", {"protocol": "udp", "dst-port": "4500"});
    ensureInputAccept($c, "l2tp: server (esp)", {"protocol": "ipsec-esp"});
}

/**
 * Turn the L2TP server off and remove its firewall openings.
 *
 * @param {Client} c an open client
 */
export func disableL2tpServer(c as Client) {
    mikrotik.run($c.session, L2TP_SERVER_PATH + "/set", {"enabled": "no"});
    removeInputAcceptsByPrefix($c, "l2tp: server (");
}

/**
 * List the L2TP clients (dial-out tunnels).
 *
 * @param {Client} c an open client
 * @return {list of L2tpClient} all L2TP clients
 */
export func l2tpClients(c as Client) {
    def rows as list of map of string to string init getAll($c, L2TP_CLIENT_PATH);
    def out as list of L2tpClient init [];
    for (def row in $rows) {
        $out[] = l2tpClientFromRow($row);
    }
    return $out;
}

/**
 * Dial out to a remote L2TP server (create an L2TP client).
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the client interface
 * @param {string} serverAddress the server's address or DNS name
 * @param {string} user          the login on the server
 * @param {string} password      its password
 * @return {string} the RouterOS id of the (new or existing) client
 * @throws {Error} kind "routeros" on bad input
 */
export func addL2tpClient(c as Client, name as string, serverAddress as string, user as string, password as string) {
    def none as map of string to string init {};
    return vpnClientAdd($c, L2TP_CLIENT_PATH, "L2TP", $name, $serverAddress, $user, $password, $none);
}

/**
 * Remove an L2TP client.
 *
 * @param {Client} c    an open client
 * @param {string} name the client interface name
 * @throws {Error} kind "routeros" when no such client exists
 */
export func removeL2tpClient(c as Client, name as string) {
    remove($c, L2TP_CLIENT_PATH, requiredId($c, L2TP_CLIENT_PATH, $name, "L2TP client"));
}

/**
 * Fold a reply row into an L2tpServer.
 *
 * @param {map of string to string} row the "/interface/l2tp-server/server" row
 * @return {L2tpServer} the typed server state
 * @internal
 */
func l2tpServerFromRow(row as map of string to string) {
    return L2tpServer{
        enabled: rowBool($row, "enabled"),
        useIpsec: rowValue($row, "use-ipsec") != "no" and rowValue($row, "use-ipsec") != "",
        defaultProfile: rowValue($row, "default-profile")
    };
}

/**
 * Fold a reply row into an L2tpClient.
 *
 * @param {map of string to string} row an "/interface/l2tp-client/print" row
 * @return {L2tpClient} the typed client
 * @internal
 */
func l2tpClientFromRow(row as map of string to string) {
    return L2tpClient{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        connectTo: rowValue($row, "connect-to"),
        user: rowValue($row, "user"),
        running: rowBool($row, "running"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
