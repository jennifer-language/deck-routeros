# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - SSTP: a TLS remote-access VPN that crosses firewalls.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the SSTP server settings (single row). */
export def const SSTP_SERVER_PATH as string init "/interface/sstp-server/server";

/** RouterOS API path of the SSTP client list (dial OUT to a server). */
export def const SSTP_CLIENT_PATH as string init "/interface/sstp-client";

/**
 * The SSTP server settings.
 *
 * @field {bool}   enabled        true when the server accepts connections
 * @field {int}    port           the TCP port it listens on (443 by default)
 * @field {string} certificate    the TLS certificate it serves
 * @field {string} defaultProfile the PPP profile applied to logins
 */
export def struct SstpServer {
    enabled as bool,
    port as int,
    certificate as string,
    defaultProfile as string
};

/**
 * One SSTP client (this router dialing out to an SSTP server).
 *
 * @field {string} id       internal RouterOS id
 * @field {string} name     the client interface name
 * @field {string} connectTo the server address
 * @field {string} user     the login on the server
 * @field {bool}   running  true when the tunnel is up
 * @field {bool}   disabled true when switched off
 * @field {string} comment  free-text comment, "" when unset
 */
export def struct SstpClient {
    id as string,
    name as string,
    connectTo as string,
    user as string,
    running as bool,
    disabled as bool,
    comment as string
};

/**
 * Read the SSTP server settings.
 *
 * @param {Client} c an open client
 * @return {SstpServer} the server state
 */
export func sstpServerStatus(c as Client) {
    return sstpServerFromRow(singleRow($c, SSTP_SERVER_PATH));
}

/**
 * Turn on an SSTP remote-access VPN server.
 *
 * SSTP rides TLS on TCP 443, so it looks like HTTPS and slips through
 * restrictive firewalls and captive networks where L2TP/IKE is blocked.
 * It needs a TLS certificate (see the certificates topic - a public
 * Let's Encrypt cert lets built-in clients connect without warnings; a
 * self-signed one means importing it on each client). Opens the
 * firewall for the chosen port. Add logins with `addVpnUser`.
 * Idempotent.
 *
 * @param {Client} c           an open client
 * @param {string} certificate the TLS certificate's store name
 * @param {int}    port        the TCP port (443 to blend in with HTTPS)
 * @throws {Error} kind "routeros" on a bad port or unknown certificate
 * @example
 *   mt.enableSstpServer($c, "router-le-cert", 443);
 *   mt.addVpnUser($c, "bob", "his password", "sstp", "remote worker");
 */
export func enableSstpServer(c as Client, certificate as string, port as int) {
    ensurePort($port);
    requiredId($c, CERTIFICATE_PATH, $certificate, "certificate");
    mikrotik.run($c.session, SSTP_SERVER_PATH + "/set",
        {"enabled": "yes", "certificate": $certificate, "port": convert.toString($port)});
    ensureInputAccept($c, "sstp: server", {"protocol": "tcp", "dst-port": convert.toString($port)});
}

/**
 * Turn the SSTP server off and remove its firewall opening.
 *
 * @param {Client} c an open client
 */
export func disableSstpServer(c as Client) {
    mikrotik.run($c.session, SSTP_SERVER_PATH + "/set", {"enabled": "no"});
    removeInputAcceptsByPrefix($c, "sstp: server");
}

/**
 * List the SSTP clients (dial-out tunnels).
 *
 * @param {Client} c an open client
 * @return {list of SstpClient} all SSTP clients
 */
export func sstpClients(c as Client) {
    def rows as list of map of string to string init getAll($c, SSTP_CLIENT_PATH);
    def out as list of SstpClient init [];
    for (def row in $rows) {
        $out[] = sstpClientFromRow($row);
    }
    return $out;
}

/**
 * Dial out to a remote SSTP server (create an SSTP client).
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the client interface
 * @param {string} serverAddress the server's address or DNS name
 * @param {string} user          the login on the server
 * @param {string} password      its password
 * @return {string} the RouterOS id of the (new or existing) client
 * @throws {Error} kind "routeros" on bad input
 */
export func addSstpClient(c as Client, name as string, serverAddress as string, user as string, password as string) {
    def extra as map of string to string init {"verify-server-certificate": "no"};
    return vpnClientAdd($c, SSTP_CLIENT_PATH, "SSTP", $name, $serverAddress, $user, $password, $extra);
}

/**
 * Remove an SSTP client.
 *
 * @param {Client} c    an open client
 * @param {string} name the client interface name
 * @throws {Error} kind "routeros" when no such client exists
 */
export func removeSstpClient(c as Client, name as string) {
    remove($c, SSTP_CLIENT_PATH, requiredId($c, SSTP_CLIENT_PATH, $name, "SSTP client"));
}

/**
 * Fold a reply row into an SstpServer.
 *
 * @param {map of string to string} row the "/interface/sstp-server/server" row
 * @return {SstpServer} the typed server state
 * @internal
 */
func sstpServerFromRow(row as map of string to string) {
    return SstpServer{
        enabled: rowBool($row, "enabled"),
        port: rowInt($row, "port"),
        certificate: rowValue($row, "certificate"),
        defaultProfile: rowValue($row, "default-profile")
    };
}

/**
 * Fold a reply row into an SstpClient.
 *
 * @param {map of string to string} row an "/interface/sstp-client/print" row
 * @return {SstpClient} the typed client
 * @internal
 */
func sstpClientFromRow(row as map of string to string) {
    return SstpClient{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        connectTo: rowValue($row, "connect-to"),
        user: rowValue($row, "user"),
        running: rowBool($row, "running"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
