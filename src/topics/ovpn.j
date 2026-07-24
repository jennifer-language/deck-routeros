# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - OpenVPN: the cross-platform remote-access VPN.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the OpenVPN server settings (single row). */
export def const OVPN_SERVER_PATH as string init "/interface/ovpn-server/server";

/** RouterOS API path of the OpenVPN client list (dial OUT to a server). */
export def const OVPN_CLIENT_PATH as string init "/interface/ovpn-client";

/**
 * The OpenVPN server settings.
 *
 * @field {bool}   enabled        true when the server accepts connections
 * @field {int}    port           the port it listens on (1194 by default)
 * @field {string} mode           "ip" (routed / tun) or "ethernet" (bridged / tap)
 * @field {string} certificate    the TLS certificate it serves
 * @field {string} defaultProfile the PPP profile applied to logins
 */
export def struct OvpnServer {
    enabled as bool,
    port as int,
    mode as string,
    certificate as string,
    defaultProfile as string
};

/**
 * One OpenVPN client (this router dialing out to an OpenVPN server).
 *
 * @field {string} id        internal RouterOS id
 * @field {string} name      the client interface name
 * @field {string} connectTo the server address
 * @field {string} user      the login on the server
 * @field {bool}   running   true when the tunnel is up
 * @field {bool}   disabled  true when switched off
 * @field {string} comment   free-text comment, "" when unset
 */
export def struct OvpnClient {
    id as string,
    name as string,
    connectTo as string,
    user as string,
    running as bool,
    disabled as bool,
    comment as string
};

/**
 * Read the OpenVPN server settings.
 *
 * @param {Client} c an open client
 * @return {OvpnServer} the server state
 */
export func ovpnServerStatus(c as Client) {
    return ovpnServerFromRow(singleRow($c, OVPN_SERVER_PATH));
}

/**
 * Turn on a routed (tun) OpenVPN remote-access server.
 *
 * OpenVPN is the portable standard: a client exists for every OS, and
 * TLS-over-TCP crosses firewalls like SSTP. RouterOS's OpenVPN needs a
 * TLS certificate (certificates topic) and, on the client side, a
 * matching config profile - so it is less plug-and-play than L2TP.
 * Opens the firewall for the chosen port. Add logins with `addVpnUser`.
 * Idempotent.
 *
 * @param {Client} c           an open client
 * @param {string} certificate the TLS certificate's store name
 * @param {int}    port        the port (1194 is the OpenVPN default)
 * @throws {Error} kind "routeros" on a bad port or unknown certificate
 * @example
 *   mt.enableOvpnServer($c, "router-le-cert", 1194);
 *   mt.addVpnUser($c, "carol", "her password", "ovpn", "laptop");
 */
export func enableOvpnServer(c as Client, certificate as string, port as int) {
    ensurePort($port);
    requiredId($c, CERTIFICATE_PATH, $certificate, "certificate");
    mikrotik.run($c.session, OVPN_SERVER_PATH + "/set", {
        "enabled": "yes",
        "certificate": $certificate,
        "port": convert.toString($port),
        "mode": "ip"
    });
    ensureInputAccept($c, "ovpn: server", {"protocol": "tcp", "dst-port": convert.toString($port)});
}

/**
 * Turn the OpenVPN server off and remove its firewall opening.
 *
 * @param {Client} c an open client
 */
export func disableOvpnServer(c as Client) {
    mikrotik.run($c.session, OVPN_SERVER_PATH + "/set", {"enabled": "no"});
    removeInputAcceptsByPrefix($c, "ovpn: server");
}

/**
 * List the OpenVPN clients (dial-out tunnels).
 *
 * @param {Client} c an open client
 * @return {list of OvpnClient} all OpenVPN clients
 */
export func ovpnClients(c as Client) {
    def rows as list of map of string to string init getAll($c, OVPN_CLIENT_PATH);
    def out as list of OvpnClient init [];
    for (def row in $rows) {
        $out[] = ovpnClientFromRow($row);
    }
    return $out;
}

/**
 * Dial out to a remote OpenVPN server (create an OpenVPN client).
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the client interface
 * @param {string} serverAddress the server's address or DNS name
 * @param {string} user          the login on the server
 * @param {string} password      its password
 * @return {string} the RouterOS id of the (new or existing) client
 * @throws {Error} kind "routeros" on bad input
 */
export func addOvpnClient(c as Client, name as string, serverAddress as string, user as string, password as string) {
    def none as map of string to string init {};
    return vpnClientAdd($c, OVPN_CLIENT_PATH, "OpenVPN", $name, $serverAddress, $user, $password, $none);
}

/**
 * Remove an OpenVPN client.
 *
 * @param {Client} c    an open client
 * @param {string} name the client interface name
 * @throws {Error} kind "routeros" when no such client exists
 */
export func removeOvpnClient(c as Client, name as string) {
    remove($c, OVPN_CLIENT_PATH, requiredId($c, OVPN_CLIENT_PATH, $name, "OpenVPN client"));
}

/**
 * Fold a reply row into an OvpnServer.
 *
 * @param {map of string to string} row the "/interface/ovpn-server/server" row
 * @return {OvpnServer} the typed server state
 * @internal
 */
func ovpnServerFromRow(row as map of string to string) {
    return OvpnServer{
        enabled: rowBool($row, "enabled"),
        port: rowInt($row, "port"),
        mode: rowValue($row, "mode"),
        certificate: rowValue($row, "certificate"),
        defaultProfile: rowValue($row, "default-profile")
    };
}

/**
 * Fold a reply row into an OvpnClient.
 *
 * @param {map of string to string} row an "/interface/ovpn-client/print" row
 * @return {OvpnClient} the typed client
 * @internal
 */
func ovpnClientFromRow(row as map of string to string) {
    return OvpnClient{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        connectTo: rowValue($row, "connect-to"),
        user: rowValue($row, "user"),
        running: rowBool($row, "running"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
