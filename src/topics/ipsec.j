# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - IPsec: standards-based site-to-site tunnels.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the IPsec peer list. */
export def const IPSEC_PEER_PATH as string init "/ip/ipsec/peer";

/** RouterOS API path of the IPsec identity list (authentication). */
export def const IPSEC_IDENTITY_PATH as string init "/ip/ipsec/identity";

/** RouterOS API path of the IPsec policy list (what gets encrypted). */
export def const IPSEC_POLICY_PATH as string init "/ip/ipsec/policy";

/** RouterOS API path of the active IPsec peers (read-only status). */
export def const IPSEC_ACTIVE_PATH as string init "/ip/ipsec/active-peers";

/** RouterOS API path of the IPsec mode-config (road-warrior client settings). */
export def const IPSEC_MODE_CONFIG_PATH as string init "/ip/ipsec/mode-config";

/**
 * One configured IPsec peer (the remote router).
 *
 * @field {string} id           internal RouterOS id
 * @field {string} name         peer name (the handle everything hangs off)
 * @field {string} address      the remote router's address or DNS name
 * @field {string} exchangeMode "ike2" for anything set up by this module
 * @field {bool}   disabled     true when switched off
 */
export def struct IpsecPeer {
    id as string,
    name as string,
    address as string,
    exchangeMode as string,
    disabled as bool
};

/**
 * One IPsec policy: which traffic gets encrypted to which peer.
 *
 * @field {string} id         internal RouterOS id
 * @field {string} peer       the peer it belongs to
 * @field {string} srcAddress the local subnet
 * @field {string} dstAddress the remote subnet
 * @field {bool}   tunnel     true for tunnel mode (site-to-site)
 * @field {bool}   active     true when the policy has a live SA
 * @field {bool}   disabled   true when switched off
 */
export def struct IpsecPolicy {
    id as string,
    peer as string,
    srcAddress as string,
    dstAddress as string,
    tunnel as bool,
    active as bool,
    disabled as bool
};

/**
 * One live IPsec negotiation with a remote router.
 *
 * @field {string} remoteAddress the other end
 * @field {string} state         negotiation state as reported
 * @field {bool}   established   computed: the state equals "established"
 * @field {string} uptime        how long the tunnel has been up
 * @field {string} side          "initiator" or "responder"
 */
export def struct IpsecActivePeer {
    remoteAddress as string,
    state as string,
    established as bool,
    uptime as string,
    side as string
};

/**
 * List the configured IPsec peers.
 *
 * @param {Client} c an open client
 * @return {list of IpsecPeer} all peers
 */
export func ipsecPeers(c as Client) {
    def rows as list of map of string to string init getAll($c, IPSEC_PEER_PATH);
    def out as list of IpsecPeer init [];
    for (def row in $rows) {
        $out[] = ipsecPeerFromRow($row);
    }
    return $out;
}

/**
 * List the IPsec policies with their live state.
 *
 * @param {Client} c an open client
 * @return {list of IpsecPolicy} all policies; `active` is the health flag
 */
export func ipsecPolicies(c as Client) {
    def rows as list of map of string to string init getAll($c, IPSEC_POLICY_PATH);
    def out as list of IpsecPolicy init [];
    for (def row in $rows) {
        $out[] = ipsecPolicyFromRow($row);
    }
    return $out;
}

/**
 * The live IPsec negotiations right now.
 *
 * @param {Client} c an open client
 * @return {list of IpsecActivePeer} check `established`
 */
export func ipsecActive(c as Client) {
    def rows as list of map of string to string init getAll($c, IPSEC_ACTIVE_PATH);
    def out as list of IpsecActivePeer init [];
    for (def row in $rows) {
        $out[] = ipsecActiveFromRow($row);
    }
    return $out;
}

/**
 * Build a complete IKEv2 site-to-site tunnel, in one call.
 *
 * Connects two LANs across the internet with standards-based IPsec -
 * the choice when the far end is another vendor (Cisco, pfSense, a
 * cloud VPN gateway) or compliance asks for IPsec; between two
 * MikroTiks, WireGuard is simpler (see the docs). Creates everything
 * the tunnel needs:
 *
 * - the peer (IKEv2) and its pre-shared-key identity,
 * - the policy encrypting localSubnet <-> remoteSubnet,
 * - the NAT bypass (an accept rule placed BEFORE masquerade - without
 *   it, NAT mangles the traffic before IPsec sees it: the classic
 *   silent failure),
 * - firewall input accepts for IKE (udp 500), NAT-T (udp 4500), and
 *   ESP.
 *
 * The far end mirrors the call: your address as its peer, the SAME
 * pre-shared key, and the subnets swapped. Idempotent by name.
 *
 * @param {Client} c            an open client
 * @param {string} name         name for the tunnel (peer, comments)
 * @param {string} peerAddress  the remote router's public address or DNS name
 * @param {string} psk          the shared secret - long and random; it
 *                              is the tunnel's entire authentication
 * @param {string} localSubnet  this site's LAN as CIDR (e.g. "192.168.10.0/24")
 * @param {string} remoteSubnet the far site's LAN as CIDR (e.g. "192.168.20.0/24")
 * @return {string} the RouterOS id of the peer
 * @throws {Error} kind "routeros" on bad input or a taken name
 * @example
 *   mt.setupIpsecTunnel($c, "tobranch", "203.0.113.99",
 *       "a long random shared secret", "192.168.10.0/24", "192.168.20.0/24");
 */
export func setupIpsecTunnel(c as Client, name as string, peerAddress as string, psk as string, localSubnet as string, remoteSubnet as string) {
    ensureName($name, "IPsec tunnel");
    def remote as string init strings.trim($peerAddress);
    ensureHost($remote);
    if (strings.trim($psk) == "") {
        raiseError("the pre-shared key must not be empty - it is the tunnel's entire authentication");
    }
    ensureCidr($localSubnet);
    ensureCidr($remoteSubnet);
    def existing as string init idByName($c, IPSEC_PEER_PATH, $name);
    if ($existing != "") {
        return $existing;
    }
    def peerId as string init add($c, IPSEC_PEER_PATH,
        {"name": $name, "address": $remote, "exchange-mode": "ike2"});
    add($c, IPSEC_IDENTITY_PATH,
        {"peer": $name, "auth-method": "pre-shared-key", "secret": $psk});
    add($c, IPSEC_POLICY_PATH, {
        "peer": $name,
        "tunnel": "yes",
        "src-address": $localSubnet,
        "dst-address": $remoteSubnet
    });
    ipsecNatBypass($c, $name, $localSubnet, $remoteSubnet);
    ipsecFirewallAccepts($c, $name, $remote);
    return $peerId;
}

/**
 * Tear an IPsec tunnel down: policy, identity, peer, NAT bypass, and
 * the firewall accepts.
 *
 * @param {Client} c    an open client
 * @param {string} name the name given to `setupIpsecTunnel`
 * @throws {Error} kind "routeros" when nothing of the tunnel exists
 */
export func teardownIpsecTunnel(c as Client, name as string) {
    def found as int init 0;
    def policyRows as list of map of string to string init getAll($c, IPSEC_POLICY_PATH);
    for (def row in $policyRows) {
        if (rowValue($row, "peer") == $name) {
            remove($c, IPSEC_POLICY_PATH, rowValue($row, ".id"));
            $found = $found + 1;
        }
    }
    def identityRows as list of map of string to string init getAll($c, IPSEC_IDENTITY_PATH);
    for (def row in $identityRows) {
        if (rowValue($row, "peer") == $name) {
            remove($c, IPSEC_IDENTITY_PATH, rowValue($row, ".id"));
            $found = $found + 1;
        }
    }
    def peerId as string init idByName($c, IPSEC_PEER_PATH, $name);
    if ($peerId != "") {
        remove($c, IPSEC_PEER_PATH, $peerId);
        $found = $found + 1;
    }
    def natRows as list of map of string to string init getAll($c, NAT_PATH);
    for (def row in $natRows) {
        if (rowValue($row, "comment") == "ipsec: " + $name + " (nat bypass)") {
            remove($c, NAT_PATH, rowValue($row, ".id"));
            $found = $found + 1;
        }
    }
    def fwRows as list of map of string to string init getAll($c, FIREWALL_PATH);
    for (def row in $fwRows) {
        if (strings.startsWith(rowValue($row, "comment"), "ipsec: " + $name + " (")) {
            remove($c, FIREWALL_PATH, rowValue($row, ".id"));
            $found = $found + 1;
        }
    }
    if ($found == 0) {
        raiseError("no IPsec tunnel named \"" + $name + "\" was found");
    }
}

/**
 * Insert the srcnat accept that keeps masquerade off tunnel traffic.
 *
 * Placed before the first srcnat rule so it wins against masquerade;
 * idempotent by comment.
 *
 * @param {Client} c            an open client
 * @param {string} name         the tunnel name (for the comment)
 * @param {string} localSubnet  this site's LAN
 * @param {string} remoteSubnet the far site's LAN
 * @internal
 */
func ipsecNatBypass(c as Client, name as string, localSubnet as string, remoteSubnet as string) {
    def rows as list of map of string to string init getAll($c, NAT_PATH);
    def comment as string init "ipsec: " + $name + " (nat bypass)";
    def existing as map of string to string init findRowByField($rows, "comment", $comment);
    if (len($existing) > 0) {
        return;
    }
    def attrs as map of string to string init {
        "chain": CHAIN_SRCNAT,
        "action": "accept",
        "src-address": $localSubnet,
        "dst-address": $remoteSubnet,
        "comment": $comment
    };
    def anchor as string init firstChainRowId($rows, CHAIN_SRCNAT);
    if ($anchor != "") {
        $attrs["place-before"] = $anchor;
    }
    add($c, NAT_PATH, $attrs);
}

/**
 * Open the firewall input chain for IKE, NAT-T, and ESP from the peer.
 *
 * Idempotent per rule via comments "ipsec: <name> (ike|nat-t|esp)".
 *
 * @param {Client} c      an open client
 * @param {string} name   the tunnel name
 * @param {string} remote the peer's address (used as src match when an IP)
 * @internal
 */
func ipsecFirewallAccepts(c as Client, name as string, remote as string) {
    def fwRows as list of map of string to string init getAll($c, FIREWALL_PATH);
    def kinds as list of string init ["ike", "nat-t", "esp"];
    for (def kind in $kinds) {
        def comment as string init "ipsec: " + $name + " (" + $kind + ")";
        def existing as map of string to string init findRowByField($fwRows, "comment", $comment);
        if (len($existing) == 0) {
            def attrs as map of string to string init
                {"chain": CHAIN_INPUT, "action": ACTION_ACCEPT, "comment": $comment};
            if ($kind == "ike") {
                $attrs["protocol"] = "udp";
                $attrs["dst-port"] = "500";
            } elseif ($kind == "nat-t") {
                $attrs["protocol"] = "udp";
                $attrs["dst-port"] = "4500";
            } else {
                $attrs["protocol"] = "ipsec-esp";
            }
            if (isIpAddress($remote)) {
                $attrs["src-address"] = $remote;
            }
            add($c, FIREWALL_PATH, $attrs);
        }
    }
}

/**
 * The id of the first rule in a chain, "" when the chain is empty.
 *
 * The place-before anchor for rules that must precede masquerade.
 *
 * @param {list of map of string to string} rows NAT (or filter) rows, in order
 * @param {string} chain the chain to look in
 * @return {string} the first rule's id, or ""
 * @internal
 */
func firstChainRowId(rows as list of map of string to string, chain as string) {
    for (def row in $rows) {
        if (rowValue($row, "chain") == $chain) {
            return rowValue($row, ".id");
        }
    }
    return "";
}

/**
 * Fold a reply row into an IpsecPeer.
 *
 * @param {map of string to string} row an "/ip/ipsec/peer/print" row
 * @return {IpsecPeer} the typed peer
 * @internal
 */
func ipsecPeerFromRow(row as map of string to string) {
    return IpsecPeer{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        address: rowValue($row, "address"),
        exchangeMode: rowValue($row, "exchange-mode"),
        disabled: rowBool($row, "disabled")
    };
}

/**
 * Fold a reply row into an IpsecPolicy.
 *
 * @param {map of string to string} row an "/ip/ipsec/policy/print" row
 * @return {IpsecPolicy} the typed policy
 * @internal
 */
func ipsecPolicyFromRow(row as map of string to string) {
    return IpsecPolicy{
        id: rowValue($row, ".id"),
        peer: rowValue($row, "peer"),
        srcAddress: rowValue($row, "src-address"),
        dstAddress: rowValue($row, "dst-address"),
        tunnel: rowBool($row, "tunnel"),
        active: rowBool($row, "active"),
        disabled: rowBool($row, "disabled")
    };
}

/**
 * Stand up an IKEv2 road-warrior server (native-client remote access).
 *
 * The IPsec counterpart to L2TP but with no L2TP layer: modern devices
 * (iOS/macOS "IKEv2", Windows, strongSwan) dial straight in. This sets
 * up EAP-MSCHAPv2 auth (users from RADIUS - see the radius topic - or a
 * user manager), hands clients an address from a pool, and installs the
 * dynamic-policy peer + identity. The router authenticates itself with
 * a TLS certificate (certificates topic), so clients get a trustable
 * server. Opens the firewall for IKE/NAT-T/ESP. Idempotent by name.
 *
 * This is the most involved VPN to get right end-to-end (certificate
 * trust chain, EAP user source); treat the result as a starting point
 * and verify against a real client. Between two networks you control,
 * WireGuard or `setupIpsecTunnel` is far simpler.
 *
 * @param {Client} c           an open client
 * @param {string} name        name for the setup (peer, mode-config, comments)
 * @param {string} certificate the router's TLS certificate store name
 * @param {string} poolRange   client address range (e.g. "10.200.0.10-10.200.0.200")
 * @param {string} dns         DNS server handed to clients (e.g. "10.200.0.1")
 * @return {string} the RouterOS id of the peer
 * @throws {Error} kind "routeros" on bad input or a taken name
 * @example
 *   mt.setupIkev2Server($c, "roadwarriors", "router-le-cert",
 *       "10.200.0.10-10.200.0.200", "1.1.1.1");
 *   # add EAP users via RADIUS, or /ip/ipsec identity with the generic verbs
 */
export func setupIkev2Server(c as Client, name as string, certificate as string, poolRange as string, dns as string) {
    ensureName($name, "IKEv2 server");
    requiredId($c, CERTIFICATE_PATH, $certificate, "certificate");
    ensureIpAddress($dns);
    if (idByName($c, IPSEC_PEER_PATH, $name) != "") {
        raiseError("the IKEv2 server \"" + $name + "\" already exists");
    }
    if (idByName($c, IP_POOL_PATH, $name) == "") {
        add($c, IP_POOL_PATH, {"name": $name, "ranges": strings.trim($poolRange)});
    }
    if (idByName($c, IPSEC_MODE_CONFIG_PATH, $name) == "") {
        add($c, IPSEC_MODE_CONFIG_PATH,
            {"name": $name, "address-pool": $name, "address-prefix-length": "32", "static-dns": strings.trim($dns)});
    }
    def peerId as string init add($c, IPSEC_PEER_PATH, {
        "name": $name,
        "exchange-mode": "ike2",
        "passive": "yes",
        "send-initial-contact": "no"
    });
    add($c, IPSEC_IDENTITY_PATH, {
        "peer": $name,
        "auth-method": "eap-radius",
        "certificate": $certificate,
        "generate-policy": "port-strict",
        "mode-config": $name
    });
    ipsecFirewallAccepts($c, $name, "");
    return $peerId;
}

/**
 * Fold a reply row into an IpsecActivePeer.
 *
 * `established` is computed here: the state equals "established".
 *
 * @param {map of string to string} row an "/ip/ipsec/active-peers/print" row
 * @return {IpsecActivePeer} the typed live peer
 * @internal
 */
func ipsecActiveFromRow(row as map of string to string) {
    def state as string init rowValue($row, "state");
    return IpsecActivePeer{
        remoteAddress: rowValue($row, "remote-address"),
        state: $state,
        established: $state == "established",
        uptime: rowValue($row, "uptime"),
        side: rowValue($row, "side")
    };
}
