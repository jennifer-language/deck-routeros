# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - DHCP server, leases, and the WAN-side DHCP client.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the address-pool list (DHCP hands these out). */
export def const IP_POOL_PATH as string init "/ip/pool";

/** RouterOS API path of the DHCP server list. */
export def const DHCP_SERVER_PATH as string init "/ip/dhcp-server";

/** RouterOS API path of the DHCP network list (gateway / DNS per subnet). */
export def const DHCP_NETWORK_PATH as string init "/ip/dhcp-server/network";

/** RouterOS API path of the DHCP lease list. */
export def const DHCP_LEASE_PATH as string init "/ip/dhcp-server/lease";

/** RouterOS API path of the DHCP client list (the WAN side). */
export def const DHCP_CLIENT_PATH as string init "/ip/dhcp-client";

/** RouterOS API path of the DHCP relay list. */
export def const DHCP_RELAY_PATH as string init "/ip/dhcp-relay";

/**
 * One DHCP server instance.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} name          server name
 * @field {string} interfaceName interface the server listens on
 * @field {string} addressPool   pool it hands addresses out of
 * @field {string} leaseTime     how long a lease lasts (e.g. "30m")
 * @field {bool}   disabled      true when the server is switched off
 */
export def struct DhcpServer {
    id as string,
    name as string,
    interfaceName as string,
    addressPool as string,
    leaseTime as string,
    disabled as bool
};

/**
 * One DHCP lease: an address handed out to (or reserved for) a device.
 *
 * @field {string} id           internal RouterOS id
 * @field {string} address      the leased IP address
 * @field {string} mac          the device's MAC address
 * @field {string} hostName     the name the device reported, "" when none
 * @field {string} server       the DHCP server that owns the lease
 * @field {string} status       lease state ("bound", "waiting", ...)
 * @field {bool}   dynamic      true for an automatic lease, false for a static reservation
 * @field {string} expiresAfter time until the lease runs out, "" for static
 * @field {string} comment      free-text comment, "" when unset
 */
export def struct DhcpLease {
    id as string,
    address as string,
    mac as string,
    hostName as string,
    server as string,
    status as string,
    dynamic as bool,
    expiresAfter as string,
    comment as string
};

/**
 * One DHCP client: an interface that asks another network (usually the
 * ISP) for its address - the typical WAN configuration.
 *
 * @field {string} id              internal RouterOS id
 * @field {string} interfaceName   interface the client runs on (the WAN port)
 * @field {string} status          "bound" when an address was obtained;
 *                                 "searching..." while still asking
 * @field {bool}   bound           true when the status is "bound"
 * @field {string} address         the address the ISP handed out (with prefix)
 * @field {string} gateway         the ISP's gateway
 * @field {string} primaryDns      DNS server the ISP announced, "" when none
 * @field {string} secondaryDns    second DNS server, "" when none
 * @field {string} expiresAfter    time until the lease must be renewed
 * @field {bool}   usePeerDns      true when the router adopts the ISP's DNS servers
 * @field {string} addDefaultRoute whether the client installs the default
 *                                 route ("yes" / "no" / "special-classless")
 * @field {bool}   disabled        true when the client is switched off
 * @field {string} comment         free-text comment, "" when unset
 */
export def struct DhcpClient {
    id as string,
    interfaceName as string,
    status as string,
    bound as bool,
    address as string,
    gateway as string,
    primaryDns as string,
    secondaryDns as string,
    expiresAfter as string,
    usePeerDns as bool,
    addDefaultRoute as string,
    disabled as bool,
    comment as string
};

/**
 * List every DHCP server instance on the router.
 *
 * @param {Client} c an open client
 * @return {list of DhcpServer} all DHCP servers
 */
export func dhcpServers(c as Client) {
    def rows as list of map of string to string init getAll($c, DHCP_SERVER_PATH);
    def out as list of DhcpServer init [];
    for (def row in $rows) {
        $out[] = dhcpServerFromRow($row);
    }
    return $out;
}

/**
 * Set up a complete, working DHCP server in one call.
 *
 * RouterOS needs three separate objects for DHCP to work - an address
 * pool, the server itself, and a network entry (gateway + DNS for the
 * clients). This creates all three, cross-checked: the gateway and the
 * pool range must lie inside the network, and the interface must exist.
 * The pool shares the server's name, so `teardownDhcp` can undo
 * everything.
 *
 * Note: the interface itself needs an address inside the network too
 * (see `addIpAddress`) - clients get a gateway they can only reach if
 * the router is actually on that network.
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the server and its pool (e.g. "dhcplan")
 * @param {string} interfaceName interface (or bridge) to serve on
 * @param {string} network       the client network as CIDR (e.g. "192.168.88.0/24")
 * @param {string} gateway       gateway address for the clients, inside `network`
 *                               (usually the router's own address there)
 * @param {string} rangeFrom     first address to hand out, inside `network`
 * @param {string} rangeTo       last address to hand out, inside `network`
 * @param {string} dns           DNS server(s) for the clients, comma-separated
 *                               (the gateway itself, if the router resolves -
 *                               see `allowRemoteDnsRequests`)
 * @return {string} the RouterOS id of the DHCP server
 * @throws {Error} kind "routeros" when a value is malformed or inconsistent
 * @example
 *   mt.addIpAddress($c, "192.168.77.1/24", "brlan");
 *   mt.setupDhcp($c, "dhcplan", "brlan", "192.168.77.0/24",
 *       "192.168.77.1", "192.168.77.10", "192.168.77.199", "192.168.77.1");
 */
export func setupDhcp(c as Client, name as string, interfaceName as string, network as string, gateway as string, rangeFrom as string, rangeTo as string, dns as string) {
    ensureName($name, "DHCP server");
    ensureCidr($network);
    ensureIpAddress($gateway);
    ensureIpAddress($rangeFrom);
    ensureIpAddress($rangeTo);
    def servers as string init normalizedAddressList($dns);
    ensureInNetwork($network, $gateway, "gateway");
    ensureInNetwork($network, $rangeFrom, "range start");
    ensureInNetwork($network, $rangeTo, "range end");
    requiredId($c, INTERFACE_PATH, $interfaceName, "interface");
    add($c, IP_POOL_PATH, {"name": $name, "ranges": $rangeFrom + "-" + $rangeTo});
    def serverId as string init add($c, DHCP_SERVER_PATH,
        {"name": $name, "interface": $interfaceName, "address-pool": $name});
    add($c, DHCP_NETWORK_PATH, {"address": $network, "gateway": $gateway, "dns-server": $servers});
    return $serverId;
}

/**
 * Undo a `setupDhcp`: remove the server, its pool, and the network entry.
 *
 * Each of the three pieces is removed if present, so a half-finished
 * setup tears down cleanly too. For finer control use the generic verbs
 * (`removeByName` on DHCP_SERVER_PATH / IP_POOL_PATH).
 *
 * @param {Client} c       an open client
 * @param {string} name    the name given to `setupDhcp`
 * @param {string} network the client network as CIDR, as given to `setupDhcp`
 * @throws {Error} kind "routeros" when none of the three pieces exists
 */
export func teardownDhcp(c as Client, name as string, network as string) {
    def found as int init 0;
    def serverId as string init idByName($c, DHCP_SERVER_PATH, $name);
    if ($serverId != "") {
        remove($c, DHCP_SERVER_PATH, $serverId);
        $found = $found + 1;
    }
    def poolId as string init idByName($c, IP_POOL_PATH, $name);
    if ($poolId != "") {
        remove($c, IP_POOL_PATH, $poolId);
        $found = $found + 1;
    }
    def rows as list of map of string to string init getAll($c, DHCP_NETWORK_PATH);
    def row as map of string to string init findRowByField($rows, "address", $network);
    if (len($row) > 0) {
        remove($c, DHCP_NETWORK_PATH, rowValue($row, ".id"));
        $found = $found + 1;
    }
    if ($found == 0) {
        raiseError("no DHCP setup named \"" + $name + "\" for network \"" + $network + "\" was found");
    }
}

/**
 * List every DHCP lease: addresses handed out and static reservations.
 *
 * @param {Client} c an open client
 * @return {list of DhcpLease} all leases
 */
export func dhcpLeases(c as Client) {
    def rows as list of map of string to string init getAll($c, DHCP_LEASE_PATH);
    def out as list of DhcpLease init [];
    for (def row in $rows) {
        $out[] = dhcpLeaseFromRow($row);
    }
    return $out;
}

/**
 * Reserve a fixed IP address for one device (a static lease).
 *
 * The device keeps getting `address` every time it asks, identified by
 * its MAC address.
 *
 * @param {Client} c       an open client
 * @param {string} address the address to reserve (e.g. "192.168.88.50")
 * @param {string} mac     the device's MAC address ("AA:BB:CC:DD:EE:FF",
 *                         case-insensitive)
 * @param {string} comment friendly note about the device (e.g. "printer")
 * @return {string} the RouterOS id of the reservation
 * @throws {Error} kind "routeros" on a malformed address or MAC
 */
export func addStaticLease(c as Client, address as string, mac as string, comment as string) {
    ensureIpAddress($address);
    ensureMac($mac);
    def attrs as map of string to string init
        {"address": $address, "mac-address": strings.upper($mac)};
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, DHCP_LEASE_PATH, $attrs);
}

/**
 * Remove the lease or reservation held by a MAC address.
 *
 * @param {Client} c   an open client
 * @param {string} mac the device's MAC address
 * @throws {Error} kind "routeros" on a malformed MAC or when no lease exists
 */
export func removeLeaseByMac(c as Client, mac as string) {
    ensureMac($mac);
    def rows as list of map of string to string init getAll($c, DHCP_LEASE_PATH);
    def row as map of string to string init findRowByField($rows, "mac-address", strings.upper($mac));
    if (len($row) == 0) {
        raiseError("no DHCP lease for MAC \"" + $mac + "\" was found");
    }
    remove($c, DHCP_LEASE_PATH, rowValue($row, ".id"));
}

/**
 * List every DHCP client on the router.
 *
 * @param {Client} c an open client
 * @return {list of DhcpClient} all DHCP clients with their lease state
 */
export func dhcpClients(c as Client) {
    def rows as list of map of string to string init getAll($c, DHCP_CLIENT_PATH);
    def out as list of DhcpClient init [];
    for (def row in $rows) {
        $out[] = dhcpClientFromRow($row);
    }
    return $out;
}

/**
 * Configure an interface as the WAN port: ask the ISP for an address.
 *
 * Starts a DHCP client with the defaults a home/office uplink wants -
 * the ISP's default route is installed and its DNS servers adopted.
 * Idempotent: if a DHCP client already runs on that interface, its id
 * is returned untouched. Combined with `addMasquerade` on the same
 * interface this is the complete "give the router internet" recipe.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the internet-facing interface (e.g. "ether1")
 * @return {string} the RouterOS id of the (new or existing) DHCP client
 * @throws {Error} kind "routeros" when the interface does not exist
 * @example
 *   mt.setupWan($c, "ether1");
 *   mt.addMasquerade($c, "ether1", "lan to internet");
 */
export func setupWan(c as Client, interfaceName as string) {
    return setupWanWith($c, $interfaceName, true, true);
}

/**
 * Like `setupWan`, choosing what the router adopts from the ISP.
 *
 * Say no to `addDefaultRoute` when this uplink is a backup line whose
 * route you manage yourself (`addRouteWithDistance`); say no to
 * `usePeerDns` to keep the DNS servers you set with `setDnsServers`.
 *
 * @param {Client} c               an open client
 * @param {string} interfaceName   the internet-facing interface
 * @param {bool}   usePeerDns      adopt the ISP's DNS servers
 * @param {bool}   addDefaultRoute install the ISP's default route
 * @return {string} the RouterOS id of the (new or existing) DHCP client
 * @throws {Error} kind "routeros" when the interface does not exist
 */
export func setupWanWith(c as Client, interfaceName as string, usePeerDns as bool, addDefaultRoute as bool) {
    requiredId($c, INTERFACE_PATH, $interfaceName, "interface");
    def rows as list of map of string to string init getAll($c, DHCP_CLIENT_PATH);
    def existing as map of string to string init findRowByField($rows, "interface", $interfaceName);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    return add($c, DHCP_CLIENT_PATH, {
        "interface": $interfaceName,
        "use-peer-dns": boolWord($usePeerDns),
        "add-default-route": boolWord($addDefaultRoute)
    });
}

/**
 * Read the WAN state of an interface: did we get an address, and which?
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface the DHCP client runs on
 * @return {DhcpClient} the client state; check `bound` and `address`
 * @throws {Error} kind "routeros" when no DHCP client runs on that interface
 * @example
 *   def wan as mt.DhcpClient init mt.wanStatus($c, "ether1");
 *   if ($wan.bound) { io.printf("online as %s\n", $wan.address); }
 */
export func wanStatus(c as Client, interfaceName as string) {
    def rows as list of map of string to string init getAll($c, DHCP_CLIENT_PATH);
    def row as map of string to string init findRowByField($rows, "interface", $interfaceName);
    if (len($row) == 0) {
        raiseError("no DHCP client runs on \"" + $interfaceName + "\" - set one up with setupWan");
    }
    return dhcpClientFromRow($row);
}

/**
 * Ask the ISP for a fresh lease now (DHCP renew).
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface the DHCP client runs on
 * @throws {Error} kind "routeros" when no DHCP client runs on that interface
 */
export func renewWan(c as Client, interfaceName as string) {
    apiRun($c, DHCP_CLIENT_PATH + "/renew",
        {".id": requiredDhcpClientId($c, $interfaceName)});
}

/**
 * Remove the DHCP client from an interface.
 *
 * The interface loses its ISP-assigned address, default route, and DNS
 * servers - the uplink goes down until reconfigured.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface the DHCP client runs on
 * @throws {Error} kind "routeros" when no DHCP client runs on that interface
 */
export func removeDhcpClient(c as Client, interfaceName as string) {
    remove($c, DHCP_CLIENT_PATH, requiredDhcpClientId($c, $interfaceName));
}

/**
 * Switch the DHCP client on an interface on.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface the DHCP client runs on
 * @throws {Error} kind "routeros" when no DHCP client runs on that interface
 */
export func enableDhcpClient(c as Client, interfaceName as string) {
    enable($c, DHCP_CLIENT_PATH, requiredDhcpClientId($c, $interfaceName));
}

/**
 * Switch the DHCP client on an interface off.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface the DHCP client runs on
 * @throws {Error} kind "routeros" when no DHCP client runs on that interface
 */
export func disableDhcpClient(c as Client, interfaceName as string) {
    disable($c, DHCP_CLIENT_PATH, requiredDhcpClientId($c, $interfaceName));
}

/**
 * Fold a reply row into a DhcpServer.
 *
 * @param {map of string to string} row an "/ip/dhcp-server/print" row
 * @return {DhcpServer} the typed server
 * @internal
 */
func dhcpServerFromRow(row as map of string to string) {
    return DhcpServer{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        interfaceName: rowValue($row, "interface"),
        addressPool: rowValue($row, "address-pool"),
        leaseTime: rowValue($row, "lease-time"),
        disabled: rowBool($row, "disabled")
    };
}

/**
 * Fold a reply row into a DhcpLease.
 *
 * @param {map of string to string} row an "/ip/dhcp-server/lease/print" row
 * @return {DhcpLease} the typed lease
 * @internal
 */
func dhcpLeaseFromRow(row as map of string to string) {
    return DhcpLease{
        id: rowValue($row, ".id"),
        address: rowValue($row, "address"),
        mac: rowValue($row, "mac-address"),
        hostName: rowValue($row, "host-name"),
        server: rowValue($row, "server"),
        status: rowValue($row, "status"),
        dynamic: rowBool($row, "dynamic"),
        expiresAfter: rowValue($row, "expires-after"),
        comment: rowValue($row, "comment")
    };
}

/**
 * Resolve an interface name to the id of its DHCP client, with a
 * friendly error when there is none.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface to look for
 * @return {string} the DHCP client id
 * @throws {Error} kind "routeros" when no DHCP client runs there
 * @internal
 */
func requiredDhcpClientId(c as Client, interfaceName as string) {
    def rows as list of map of string to string init getAll($c, DHCP_CLIENT_PATH);
    def row as map of string to string init findRowByField($rows, "interface", $interfaceName);
    if (len($row) == 0) {
        raiseError("no DHCP client runs on \"" + $interfaceName + "\" - set one up with setupWan");
    }
    return rowValue($row, ".id");
}

/**
 * Fold a reply row into a DhcpClient.
 *
 * `bound` is computed here: the status equals "bound".
 *
 * @param {map of string to string} row an "/ip/dhcp-client/print" row
 * @return {DhcpClient} the typed client state
 * @internal
 */
func dhcpClientFromRow(row as map of string to string) {
    def status as string init rowValue($row, "status");
    return DhcpClient{
        id: rowValue($row, ".id"),
        interfaceName: rowValue($row, "interface"),
        status: $status,
        bound: $status == "bound",
        address: rowValue($row, "address"),
        gateway: rowValue($row, "gateway"),
        primaryDns: rowValue($row, "primary-dns"),
        secondaryDns: rowValue($row, "secondary-dns"),
        expiresAfter: rowValue($row, "expires-after"),
        usePeerDns: rowBool($row, "use-peer-dns"),
        addDefaultRoute: rowValue($row, "add-default-route"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * One DHCP relay: forwards DHCP requests from a local network to a
 * remote DHCP server.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} name          the relay name
 * @field {string} interfaceName the interface whose clients are relayed
 * @field {string} dhcpServer    the remote DHCP server's address
 * @field {bool}   disabled      true when switched off
 */
export def struct DhcpRelay {
    id as string,
    name as string,
    interfaceName as string,
    dhcpServer as string,
    disabled as bool
};

/**
 * List the DHCP relays.
 *
 * @param {Client} c an open client
 * @return {list of DhcpRelay} all relays
 */
export func dhcpRelays(c as Client) {
    def rows as list of map of string to string init getAll($c, DHCP_RELAY_PATH);
    def out as list of DhcpRelay init [];
    for (def row in $rows) {
        $out[] = dhcpRelayFromRow($row);
    }
    return $out;
}

/**
 * Relay a network's DHCP requests to a central DHCP server.
 *
 * Instead of running a DHCP server on the router (`setupDhcp`), forward
 * the clients' requests to a DHCP server elsewhere (a central server for
 * many sites/VLANs). The interface's clients broadcast; the relay
 * unicasts to `serverAddress` and hands the reply back. The interface
 * needs an address in the client network so the server knows which
 * subnet to serve. Idempotent by name.
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the relay
 * @param {string} interfaceName the interface whose clients are relayed
 * @param {string} serverAddress the central DHCP server's address
 * @return {string} the RouterOS id of the (new or existing) relay
 * @throws {Error} kind "routeros" on a bad name, address, or unknown interface
 * @example
 *   mt.addDhcpRelay($c, "vlan20-relay", "vlanoffice", "10.0.0.5");
 */
export func addDhcpRelay(c as Client, name as string, interfaceName as string, serverAddress as string) {
    ensureName($name, "DHCP relay");
    def server as string init strings.trim($serverAddress);
    ensureIpAddress($server);
    requiredId($c, INTERFACE_PATH, $interfaceName, "interface");
    def existing as string init idByName($c, DHCP_RELAY_PATH, $name);
    if ($existing != "") {
        return $existing;
    }
    return add($c, DHCP_RELAY_PATH,
        {"name": $name, "interface": $interfaceName, "dhcp-server": $server});
}

/**
 * Remove a DHCP relay.
 *
 * @param {Client} c    an open client
 * @param {string} name the relay name
 * @throws {Error} kind "routeros" when no relay has that name
 */
export func removeDhcpRelay(c as Client, name as string) {
    remove($c, DHCP_RELAY_PATH, requiredId($c, DHCP_RELAY_PATH, $name, "DHCP relay"));
}

/**
 * Fold a reply row into a DhcpRelay.
 *
 * @param {map of string to string} row an "/ip/dhcp-relay/print" row
 * @return {DhcpRelay} the typed relay
 * @internal
 */
func dhcpRelayFromRow(row as map of string to string) {
    return DhcpRelay{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        interfaceName: rowValue($row, "interface"),
        dhcpServer: rowValue($row, "dhcp-server"),
        disabled: rowBool($row, "disabled")
    };
}
