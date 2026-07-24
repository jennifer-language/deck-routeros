# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - WireGuard VPN tunnels (RouterOS v7).
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the WireGuard interface list (needs RouterOS v7). */
export def const WIREGUARD_PATH as string init "/interface/wireguard";

/** RouterOS API path of the WireGuard peer list. */
export def const WIREGUARD_PEER_PATH as string init "/interface/wireguard/peers";

def const KEY_CHARS as string init "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

/**
 * One WireGuard interface: the local end of one or more VPN tunnels.
 *
 * The private key is deliberately not part of this struct - the router
 * generates and keeps it; only the public key (safe to share) is read.
 *
 * @field {string} id         internal RouterOS id
 * @field {string} name       interface name (e.g. "wgvpn")
 * @field {string} publicKey  the router's public key - hand this to peers
 * @field {int}    listenPort UDP port the router listens on
 * @field {string} mtu        MTU as reported
 * @field {bool}   running    true when the interface is up
 * @field {bool}   disabled   true when the interface is switched off
 * @field {string} comment    free-text comment, "" when unset
 */
export def struct WireguardInterface {
    id as string,
    name as string,
    publicKey as string,
    listenPort as int,
    mtu as string,
    running as bool,
    disabled as bool,
    comment as string
};

/**
 * One WireGuard peer: a remote party allowed through a tunnel.
 *
 * @field {string} id              internal RouterOS id
 * @field {string} interfaceName   WireGuard interface the peer belongs to
 * @field {string} publicKey       the peer's public key
 * @field {string} endpointAddress where the router dials the peer, "" when
 *                                 the peer dials in
 * @field {string} endpointPort    the peer's UDP port, "" / "0" when dialing in
 * @field {string} allowedAddress  addresses allowed (and routed) through
 *                                 this peer, comma-separated CIDRs
 * @field {string} keepalive       persistent keepalive as reported, "" when off
 * @field {string} lastHandshake   time since the last handshake - the sign
 *                                 of life of a tunnel
 * @field {string} rx              bytes received from the peer
 * @field {string} tx              bytes sent to the peer
 * @field {bool}   disabled        true when the peer is switched off
 * @field {string} comment         free-text comment; the handle for removal
 */
export def struct WireguardPeer {
    id as string,
    interfaceName as string,
    publicKey as string,
    endpointAddress as string,
    endpointPort as string,
    allowedAddress as string,
    keepalive as string,
    lastHandshake as string,
    rx as string,
    tx as string,
    disabled as bool,
    comment as string
};

/**
 * List every WireGuard interface on the router.
 *
 * Returns an empty list on routers without WireGuard (RouterOS v6).
 *
 * @param {Client} c an open client
 * @return {list of WireguardInterface} all WireGuard interfaces
 */
export func wireguardInterfaces(c as Client) {
    def out as list of WireguardInterface init [];
    def rows as list of map of string to string init [];
    try {
        $rows = getAll($c, WIREGUARD_PATH);
    } catch (e) {
        return $out;
    }
    for (def row in $rows) {
        $out[] = wireguardFromRow($row);
    }
    return $out;
}

/**
 * Create a WireGuard interface; the router generates the keypair.
 *
 * Idempotent by name: an existing interface of that name is reused.
 * After creating, read the router's public key with
 * `wireguardPublicKey` and hand it to the other side.
 *
 * @param {Client} c          an open client
 * @param {string} name       name for the interface (e.g. "wgvpn")
 * @param {int}    listenPort UDP port to listen on (e.g. 13231)
 * @return {string} the RouterOS id of the (new or existing) interface
 * @throws {Error} kind "routeros" on a bad name or port
 */
export func addWireguard(c as Client, name as string, listenPort as int) {
    ensureName($name, "WireGuard interface");
    ensurePort($listenPort);
    def existing as string init idByName($c, WIREGUARD_PATH, $name);
    if ($existing != "") {
        return $existing;
    }
    return add($c, WIREGUARD_PATH, {
        "name": $name,
        "listen-port": convert.toString($listenPort)
    });
}

/**
 * Read the router's public key for a WireGuard interface.
 *
 * This is the value the other side of the tunnel needs; it is safe to
 * share. (The private key never leaves the router through routeros.)
 *
 * @param {Client} c    an open client
 * @param {string} name the WireGuard interface name
 * @return {string} the base64 public key
 * @throws {Error} kind "routeros" when no such interface exists
 */
export func wireguardPublicKey(c as Client, name as string) {
    def row as map of string to string init findByName($c, WIREGUARD_PATH, $name);
    if (len($row) == 0) {
        raiseError("no WireGuard interface named \"" + $name + "\" was found - create one with addWireguard");
    }
    return rowValue($row, "public-key");
}

/**
 * Stand up a complete WireGuard server in one call.
 *
 * Creates the interface (keypair generated by the router), puts the
 * given VPN address on it, and opens the listen port in the firewall
 * (an accept rule on the input chain, comment "wireguard: <name>").
 * Idempotent: each of the three pieces is only created if missing, so
 * calling it again is safe. Peers are added afterwards with
 * `addWireguardPeer`.
 *
 * @param {Client} c          an open client
 * @param {string} name       name for the interface (e.g. "wgvpn")
 * @param {int}    listenPort UDP port to listen on (e.g. 13231)
 * @param {string} address    the router's address INSIDE the VPN, with
 *                            prefix (e.g. "10.100.0.1/24")
 * @return {string} the RouterOS id of the WireGuard interface
 * @throws {Error} kind "routeros" on a bad name, port, or address
 * @example
 *   mt.setupWireguardServer($c, "wgvpn", 13231, "10.100.0.1/24");
 *   io.printf("server key: %s\n", mt.wireguardPublicKey($c, "wgvpn"));
 *   mt.addWireguardPeer($c, "wgvpn", $laptopKey, "10.100.0.2/32", "laptop");
 */
export func setupWireguardServer(c as Client, name as string, listenPort as int, address as string) {
    ensureCidr($address);
    def id as string init addWireguard($c, $name, $listenPort);
    def rows as list of map of string to string init getAll($c, IP_ADDRESS_PATH);
    def existing as map of string to string init findRowByField($rows, "address", $address);
    if (len($existing) == 0) {
        add($c, IP_ADDRESS_PATH, {"address": $address, "interface": $name});
    }
    def fwComment as string init "wireguard: " + $name;
    def fwRows as list of map of string to string init getAll($c, FIREWALL_PATH);
    def fwExisting as map of string to string init findRowByField($fwRows, "comment", $fwComment);
    if (len($fwExisting) == 0) {
        allowService($c, "udp", $listenPort, $fwComment);
    }
    return $id;
}

/**
 * List WireGuard peers, with traffic counters and handshake age.
 *
 * `lastHandshake` is the health signal: a peer that handshook within
 * the last ~2 minutes is alive.
 *
 * @param {Client} c an open client
 * @return {list of WireguardPeer} all peers across all WireGuard interfaces
 */
export func wireguardPeers(c as Client) {
    def out as list of WireguardPeer init [];
    def rows as list of map of string to string init [];
    try {
        $rows = getAll($c, WIREGUARD_PEER_PATH);
    } catch (e) {
        return $out;
    }
    for (def row in $rows) {
        $out[] = wireguardPeerFromRow($row);
    }
    return $out;
}

/**
 * Allow a remote party into a tunnel (add a peer that dials in).
 *
 * The server-side shape: the peer (a laptop, a phone, another router)
 * connects to us. `allowedAddress` is the peer's address INSIDE the
 * VPN - traffic from and to it is only accepted for these addresses,
 * so a single device is "10.100.0.2/32".
 *
 * @param {Client} c              an open client
 * @param {string} interfaceName  the WireGuard interface (must exist)
 * @param {string} publicKey      the peer's public key (44 base64 characters)
 * @param {string} allowedAddress the peer's VPN address(es), CIDR,
 *                                comma-separated when several
 * @param {string} comment        friendly handle for the peer (e.g. "laptop")
 * @return {string} the RouterOS id of the new peer
 * @throws {Error} kind "routeros" on a bad key or address, or an
 *                 unknown interface
 */
export func addWireguardPeer(c as Client, interfaceName as string, publicKey as string, allowedAddress as string, comment as string) {
    requiredId($c, WIREGUARD_PATH, $interfaceName, "WireGuard interface");
    ensureWireguardKey($publicKey);
    def allowed as string init normalizedAllowedAddress($allowedAddress);
    def attrs as map of string to string init {
        "interface": $interfaceName,
        "public-key": strings.trim($publicKey),
        "allowed-address": $allowed
    };
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, WIREGUARD_PEER_PATH, $attrs);
}

/**
 * Connect out to a remote WireGuard server (add a dialing peer).
 *
 * The client-side shape: the router dials the remote endpoint and keeps
 * the tunnel alive through NAT with a 25-second keepalive. Route
 * everything through the tunnel with allowedAddress "0.0.0.0/0", or
 * just the remote networks with their CIDRs.
 *
 * @param {Client} c               an open client
 * @param {string} interfaceName   the WireGuard interface (must exist)
 * @param {string} publicKey       the server's public key
 * @param {string} endpointHost    the server's address or DNS name
 * @param {int}    endpointPort    the server's UDP port (e.g. 13231)
 * @param {string} allowedAddress  what to send through the tunnel, CIDR,
 *                                 comma-separated when several
 * @param {string} comment         friendly handle for the peer
 * @return {string} the RouterOS id of the new peer
 * @throws {Error} kind "routeros" on bad input or an unknown interface
 * @example
 *   mt.addWireguard($c, "wghome", 13231);
 *   mt.connectWireguard($c, "wghome", $serverKey, "vpn.example.org", 13231,
 *       "10.100.0.0/24", "to home network");
 *   mt.addIpAddress($c, "10.100.0.3/24", "wghome");
 */
export func connectWireguard(c as Client, interfaceName as string, publicKey as string, endpointHost as string, endpointPort as int, allowedAddress as string, comment as string) {
    requiredId($c, WIREGUARD_PATH, $interfaceName, "WireGuard interface");
    ensureWireguardKey($publicKey);
    def host as string init strings.trim($endpointHost);
    ensureHost($host);
    ensurePort($endpointPort);
    def allowed as string init normalizedAllowedAddress($allowedAddress);
    def attrs as map of string to string init {
        "interface": $interfaceName,
        "public-key": strings.trim($publicKey),
        "endpoint-address": $host,
        "endpoint-port": convert.toString($endpointPort),
        "allowed-address": $allowed,
        "persistent-keepalive": "25"
    };
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, WIREGUARD_PEER_PATH, $attrs);
}

/**
 * Remove the WireGuard peer that carries a comment.
 *
 * @param {Client} c       an open client
 * @param {string} comment the comment given to the peer when it was added
 * @throws {Error} kind "routeros" when no peer carries that comment
 */
export func removeWireguardPeerByComment(c as Client, comment as string) {
    def rows as list of map of string to string init getAll($c, WIREGUARD_PEER_PATH);
    def row as map of string to string init findRowByField($rows, "comment", $comment);
    if (len($row) == 0) {
        raiseError("no WireGuard peer with the comment \"" + $comment + "\" was found");
    }
    remove($c, WIREGUARD_PEER_PATH, rowValue($row, ".id"));
}

/**
 * Delete a WireGuard interface, its peers, and what setupWireguardServer
 * created for it.
 *
 * Removes the interface (peers go with it), any IP address sitting on
 * it, and the "wireguard: <name>" firewall rule if present.
 *
 * @param {Client} c    an open client
 * @param {string} name the WireGuard interface name
 * @throws {Error} kind "routeros" when no such interface exists
 */
export func removeWireguard(c as Client, name as string) {
    def id as string init requiredId($c, WIREGUARD_PATH, $name, "WireGuard interface");
    def addrRows as list of map of string to string init getAll($c, IP_ADDRESS_PATH);
    def addrRow as map of string to string init findRowByField($addrRows, "interface", $name);
    if (len($addrRow) > 0) {
        remove($c, IP_ADDRESS_PATH, rowValue($addrRow, ".id"));
    }
    def fwRows as list of map of string to string init getAll($c, FIREWALL_PATH);
    def fwRow as map of string to string init findRowByField($fwRows, "comment", "wireguard: " + $name);
    if (len($fwRow) > 0) {
        remove($c, FIREWALL_PATH, rowValue($fwRow, ".id"));
    }
    remove($c, WIREGUARD_PATH, $id);
}

/**
 * Switch a WireGuard interface on.
 *
 * @param {Client} c    an open client
 * @param {string} name the WireGuard interface name
 * @throws {Error} kind "routeros" when no such interface exists
 */
export func enableWireguard(c as Client, name as string) {
    enable($c, WIREGUARD_PATH, requiredId($c, WIREGUARD_PATH, $name, "WireGuard interface"));
}

/**
 * Switch a WireGuard interface off; all its tunnels go down.
 *
 * @param {Client} c    an open client
 * @param {string} name the WireGuard interface name
 * @throws {Error} kind "routeros" when no such interface exists
 */
export func disableWireguard(c as Client, name as string) {
    disable($c, WIREGUARD_PATH, requiredId($c, WIREGUARD_PATH, $name, "WireGuard interface"));
}

/**
 * Validate a WireGuard key: 44 base64 characters ending in "=".
 *
 * @param {string} key the candidate key
 * @throws {Error} kind "routeros" on any other shape
 * @internal
 */
func ensureWireguardKey(key as string) {
    def k as string init strings.trim($key);
    if (len($k) != 44 or not strings.endsWith($k, "=")) {
        raiseError("\"" + $key + "\" is not a WireGuard key - expected 44 base64 characters ending in \"=\"");
    }
    def chars as list of string init strings.chars($k);
    for (def ch in $chars) {
        if (not strings.contains(KEY_CHARS, $ch)) {
            raiseError("\"" + $key + "\" is not a WireGuard key - it contains characters outside base64");
        }
    }
}

/**
 * Validate and normalize a comma-separated allowed-address list.
 *
 * Every entry must carry a prefix - a single device is "x.x.x.x/32",
 * and that hint is in the error because a bare address is the most
 * common WireGuard configuration mistake.
 *
 * @param {string} csv the candidate list
 * @return {string} the normalized list
 * @throws {Error} kind "routeros" on an empty list or a bad entry
 * @internal
 */
func normalizedAllowedAddress(csv as string) {
    def parts as list of string init strings.split($csv, ",");
    def out as list of string init [];
    for (def part in $parts) {
        def p as string init strings.trim($part);
        if ($p == "") {
            raiseError("the allowed-address list \"" + $csv + "\" must not contain empty entries");
        }
        if (not strings.contains($p, "/")) {
            raiseError("\"" + $p + "\" is missing the prefix length - a single device is \"" + $p + "/32\"");
        }
        ensureCidr($p);
        $out[] = $p;
    }
    if (len($out) == 0) {
        raiseError("the allowed-address list must contain at least one network");
    }
    return strings.join($out, ",");
}

/**
 * Fold a reply row into a WireguardInterface.
 *
 * @param {map of string to string} row an "/interface/wireguard/print" row
 * @return {WireguardInterface} the typed interface
 * @internal
 */
func wireguardFromRow(row as map of string to string) {
    return WireguardInterface{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        publicKey: rowValue($row, "public-key"),
        listenPort: rowInt($row, "listen-port"),
        mtu: rowValue($row, "mtu"),
        running: rowBool($row, "running"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * Fold a reply row into a WireguardPeer.
 *
 * @param {map of string to string} row an "/interface/wireguard/peers/print" row
 * @return {WireguardPeer} the typed peer
 * @internal
 */
func wireguardPeerFromRow(row as map of string to string) {
    return WireguardPeer{
        id: rowValue($row, ".id"),
        interfaceName: rowValue($row, "interface"),
        publicKey: rowValue($row, "public-key"),
        endpointAddress: rowValue($row, "endpoint-address"),
        endpointPort: rowValue($row, "endpoint-port"),
        allowedAddress: rowValue($row, "allowed-address"),
        keepalive: rowValue($row, "persistent-keepalive"),
        lastHandshake: rowValue($row, "last-handshake"),
        rx: rowValue($row, "rx"),
        tx: rowValue($row, "tx"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
