# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - hotspot: a captive guest portal.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the hotspot server list. */
export def const HOTSPOT_PATH as string init "/ip/hotspot";

/** RouterOS API path of the hotspot server profiles. */
export def const HOTSPOT_PROFILE_PATH as string init "/ip/hotspot/profile";

/** RouterOS API path of the hotspot user list. */
export def const HOTSPOT_USER_PATH as string init "/ip/hotspot/user";

/** RouterOS API path of the active hotspot sessions (read-only + kick). */
export def const HOTSPOT_ACTIVE_PATH as string init "/ip/hotspot/active";

/** RouterOS API path of the hotspot IP bindings (bypass / block devices). */
export def const HOTSPOT_BINDING_PATH as string init "/ip/hotspot/ip-binding";

/** RouterOS API path of the walled garden (allowed before login). */
export def const WALLED_GARDEN_PATH as string init "/ip/hotspot/walled-garden";

/**
 * One hotspot server: a captive portal guarding an interface.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} name          server name
 * @field {string} interfaceName the guarded interface (the guest bridge)
 * @field {string} addressPool   pool the guests draw addresses from
 * @field {string} profile       server profile (portal address, login method)
 * @field {bool}   disabled      true when the portal is switched off
 */
export def struct HotspotServer {
    id as string,
    name as string,
    interfaceName as string,
    addressPool as string,
    profile as string,
    disabled as bool
};

/**
 * One hotspot user (a login for the portal).
 *
 * @field {string} id          internal RouterOS id
 * @field {string} name        login name
 * @field {string} profile     user profile ("default" unless customized)
 * @field {string} limitUptime total connect time allowed, "" for unlimited
 * @field {string} uptime      time used so far
 * @field {bool}   disabled    true when the login is switched off
 * @field {string} comment     free-text comment, "" when unset
 */
export def struct HotspotUser {
    id as string,
    name as string,
    profile as string,
    limitUptime as string,
    uptime as string,
    disabled as bool,
    comment as string
};

/**
 * One active hotspot session: a guest logged in right now.
 *
 * @field {string} user     the login used
 * @field {string} address  the guest's IP address
 * @field {string} mac      the guest's MAC address
 * @field {string} uptime   session duration so far
 * @field {string} idleTime time since the guest last sent traffic
 * @field {int}    bytesIn  bytes received from the guest
 * @field {int}    bytesOut bytes sent to the guest
 */
export def struct HotspotSession {
    user as string,
    address as string,
    mac as string,
    uptime as string,
    idleTime as string,
    bytesIn as int,
    bytesOut as int
};

/**
 * List the hotspot servers.
 *
 * @param {Client} c an open client
 * @return {list of HotspotServer} all portals
 */
export func hotspotServers(c as Client) {
    def rows as list of map of string to string init getAll($c, HOTSPOT_PATH);
    def out as list of HotspotServer init [];
    for (def row in $rows) {
        $out[] = hotspotFromRow($row);
    }
    return $out;
}

/**
 * Stand up a captive guest portal on an interface, in one call.
 *
 * Builds what RouterOS's setup wizard would: the DHCP stack for the
 * guest network (via `setupDhcp` - pool, server, network entry), a
 * hotspot profile, and the hotspot server guarding the interface.
 * Guests then get an address, and every web request is redirected to
 * the login page until they authenticate (`addHotspotUser` /
 * `addHotspotVoucher` create logins; `bypassHotspotMac` exempts
 * devices).
 *
 * Use a DEDICATED guest interface or bridge - a hotspot intercepts ALL
 * traffic on its interface, and putting it on the management LAN locks
 * everyone (including you) behind the portal. As with `setupDhcp`, the
 * interface itself needs an address inside the network first
 * (`addIpAddress`). Idempotent by name.
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the portal (and its DHCP pieces)
 * @param {string} interfaceName the guest interface/bridge (e.g. "brguest")
 * @param {string} network       the guest network as CIDR (e.g. "10.5.50.0/24")
 * @param {string} gateway       the router's address in it (e.g. "10.5.50.1")
 * @param {string} rangeFrom     first guest address
 * @param {string} rangeTo       last guest address
 * @return {string} the RouterOS id of the hotspot server
 * @throws {Error} kind "routeros" on bad input (the `setupDhcp` checks
 *                 all apply)
 * @example
 *   mt.addBridge($c, "brguest");
 *   mt.addBridgePort($c, "brguest", "wifiguest");
 *   mt.addIpAddress($c, "10.5.50.1/24", "brguest");
 *   mt.setupHotspot($c, "guests", "brguest", "10.5.50.0/24",
 *       "10.5.50.1", "10.5.50.10", "10.5.50.254");
 *   mt.addHotspotVoucher($c, "visitor", "day pass 123", "1d", "front desk");
 */
export func setupHotspot(c as Client, name as string, interfaceName as string, network as string, gateway as string, rangeFrom as string, rangeTo as string) {
    ensureName($name, "hotspot");
    def existing as string init idByName($c, HOTSPOT_PATH, $name);
    if ($existing != "") {
        return $existing;
    }
    setupDhcp($c, $name, $interfaceName, $network, $gateway, $rangeFrom, $rangeTo, $gateway);
    if (idByName($c, HOTSPOT_PROFILE_PATH, $name) == "") {
        add($c, HOTSPOT_PROFILE_PATH, {"name": $name, "hotspot-address": $gateway});
    }
    return add($c, HOTSPOT_PATH, {
        "name": $name,
        "interface": $interfaceName,
        "address-pool": $name,
        "profile": $name
    });
}

/**
 * Tear a portal down: server, profile, and the DHCP stack.
 *
 * Each piece is removed if present. Users, bindings, and walled-garden
 * entries are left (they are portal-independent) - remove them
 * explicitly if wanted.
 *
 * @param {Client} c       an open client
 * @param {string} name    the name given to `setupHotspot`
 * @param {string} network the guest network as CIDR, as given to `setupHotspot`
 * @throws {Error} kind "routeros" when nothing of the portal exists
 */
export func teardownHotspot(c as Client, name as string, network as string) {
    def found as int init 0;
    def serverId as string init idByName($c, HOTSPOT_PATH, $name);
    if ($serverId != "") {
        remove($c, HOTSPOT_PATH, $serverId);
        $found = $found + 1;
    }
    def profileId as string init idByName($c, HOTSPOT_PROFILE_PATH, $name);
    if ($profileId != "") {
        remove($c, HOTSPOT_PROFILE_PATH, $profileId);
        $found = $found + 1;
    }
    try {
        teardownDhcp($c, $name, $network);
        $found = $found + 1;
    } catch (e) {
    }
    if ($found == 0) {
        raiseError("no hotspot named \"" + $name + "\" was found");
    }
}

/**
 * List the portal logins.
 *
 * @param {Client} c an open client
 * @return {list of HotspotUser} all hotspot users
 */
export func hotspotUsers(c as Client) {
    def rows as list of map of string to string init getAll($c, HOTSPOT_USER_PATH);
    def out as list of HotspotUser init [];
    for (def row in $rows) {
        $out[] = hotspotUserFromRow($row);
    }
    return $out;
}

/**
 * Create a portal login.
 *
 * @param {Client} c        an open client
 * @param {string} name     login name guests type
 * @param {string} password its password
 * @param {string} comment  friendly note ("" for none)
 * @return {string} the RouterOS id of the user
 * @throws {Error} kind "routeros" on a bad name, empty password, or a
 *                 login that already exists
 */
export func addHotspotUser(c as Client, name as string, password as string, comment as string) {
    return hotspotUserAdd($c, $name, $password, "", $comment);
}

/**
 * Create a time-limited portal login (a voucher).
 *
 * The classic front-desk pattern: a login that stops working after its
 * total connect time is used up (e.g. a day pass).
 *
 * @param {Client} c           an open client
 * @param {string} name        login name on the voucher
 * @param {string} password    its password
 * @param {string} uptimeLimit total connect time ("4h", "1d", "1w")
 * @param {string} comment     friendly note ("" for none)
 * @return {string} the RouterOS id of the user
 * @throws {Error} kind "routeros" on bad input or an existing login
 */
export func addHotspotVoucher(c as Client, name as string, password as string, uptimeLimit as string, comment as string) {
    def limit as string init strings.trim($uptimeLimit);
    ensureSchedulerInterval($limit);
    return hotspotUserAdd($c, $name, $password, $limit, $comment);
}

/**
 * Delete a portal login.
 *
 * @param {Client} c    an open client
 * @param {string} name the login name
 * @throws {Error} kind "routeros" when no such login exists
 */
export func removeHotspotUser(c as Client, name as string) {
    remove($c, HOTSPOT_USER_PATH, requiredId($c, HOTSPOT_USER_PATH, $name, "hotspot user"));
}

/**
 * Who is logged into the portal right now, with usage.
 *
 * @param {Client} c an open client
 * @return {list of HotspotSession} the active sessions
 */
export func hotspotActive(c as Client) {
    def rows as list of map of string to string init getAll($c, HOTSPOT_ACTIVE_PATH);
    def out as list of HotspotSession init [];
    for (def row in $rows) {
        $out[] = hotspotSessionFromRow($row);
    }
    return $out;
}

/**
 * Log a guest out now (they land back on the login page).
 *
 * @param {Client} c    an open client
 * @param {string} user the login whose session to end
 * @throws {Error} kind "routeros" when that login has no active session
 */
export func kickHotspotUser(c as Client, user as string) {
    def rows as list of map of string to string init getAll($c, HOTSPOT_ACTIVE_PATH);
    def row as map of string to string init findRowByField($rows, "user", $user);
    if (len($row) == 0) {
        raiseError("\"" + $user + "\" has no active hotspot session");
    }
    remove($c, HOTSPOT_ACTIVE_PATH, rowValue($row, ".id"));
}

/**
 * Let a device through the portal without logging in (bypass).
 *
 * For the printer, the TV, the payment terminal - devices that cannot
 * click a login page. Idempotent by MAC.
 *
 * @param {Client} c       an open client
 * @param {string} mac     the device's MAC address
 * @param {string} comment friendly note (e.g. "lobby printer")
 * @return {string} the RouterOS id of the binding
 * @throws {Error} kind "routeros" on a malformed MAC
 */
export func bypassHotspotMac(c as Client, mac as string, comment as string) {
    ensureMac($mac);
    def wanted as string init strings.upper($mac);
    def rows as list of map of string to string init getAll($c, HOTSPOT_BINDING_PATH);
    def existing as map of string to string init findRowByField($rows, "mac-address", $wanted);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    def attrs as map of string to string init {"mac-address": $wanted, "type": "bypassed"};
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, HOTSPOT_BINDING_PATH, $attrs);
}

/**
 * Remove a device's portal bypass; it must log in again.
 *
 * @param {Client} c   an open client
 * @param {string} mac the device's MAC address
 * @throws {Error} kind "routeros" when no bypass exists for it
 */
export func removeHotspotBypass(c as Client, mac as string) {
    ensureMac($mac);
    def rows as list of map of string to string init getAll($c, HOTSPOT_BINDING_PATH);
    def row as map of string to string init findRowByField($rows, "mac-address", strings.upper($mac));
    if (len($row) == 0) {
        raiseError("no hotspot bypass for MAC \"" + $mac + "\" was found");
    }
    remove($c, HOTSPOT_BINDING_PATH, rowValue($row, ".id"));
}

/**
 * Allow a destination before login (walled garden).
 *
 * What unauthenticated guests may still reach: your company site, a
 * payment provider, terms-of-service pages. Idempotent by host.
 *
 * @param {Client} c       an open client
 * @param {string} dstHost the destination ("example.org"; "*.example.org" works)
 * @param {string} comment friendly note ("" for none)
 * @return {string} the RouterOS id of the entry
 * @throws {Error} kind "routeros" on an empty or spaced host
 */
export func allowBeforeLogin(c as Client, dstHost as string, comment as string) {
    def host as string init strings.trim($dstHost);
    ensureHost($host);
    def rows as list of map of string to string init getAll($c, WALLED_GARDEN_PATH);
    def existing as map of string to string init findRowByField($rows, "dst-host", $host);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    def attrs as map of string to string init {"dst-host": $host, "action": "allow"};
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, WALLED_GARDEN_PATH, $attrs);
}

/**
 * Remove a walled-garden entry.
 *
 * @param {Client} c       an open client
 * @param {string} dstHost the destination it was created for
 * @throws {Error} kind "routeros" when no such entry exists
 */
export func removeWalledGardenEntry(c as Client, dstHost as string) {
    def rows as list of map of string to string init getAll($c, WALLED_GARDEN_PATH);
    def row as map of string to string init findRowByField($rows, "dst-host", strings.trim($dstHost));
    if (len($row) == 0) {
        raiseError("no walled-garden entry for \"" + $dstHost + "\" was found");
    }
    remove($c, WALLED_GARDEN_PATH, rowValue($row, ".id"));
}

/**
 * Validate and create a hotspot user; empty limit omits the cap.
 *
 * @param {Client} c        an open client
 * @param {string} name     login name
 * @param {string} password its password
 * @param {string} limit    limit-uptime, "" for unlimited
 * @param {string} comment  note, "" for none
 * @return {string} the RouterOS id of the user
 * @throws {Error} kind "routeros" on bad input or an existing login
 * @internal
 */
func hotspotUserAdd(c as Client, name as string, password as string, limit as string, comment as string) {
    ensureName($name, "hotspot user");
    if (strings.trim($password) == "") {
        raiseError("the hotspot user password must not be empty");
    }
    if (idByName($c, HOTSPOT_USER_PATH, $name) != "") {
        raiseError("the hotspot user \"" + $name + "\" already exists");
    }
    def attrs as map of string to string init {"name": $name, "password": $password};
    if ($limit != "") {
        $attrs["limit-uptime"] = $limit;
    }
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, HOTSPOT_USER_PATH, $attrs);
}

/**
 * Fold a reply row into a HotspotServer.
 *
 * @param {map of string to string} row an "/ip/hotspot/print" row
 * @return {HotspotServer} the typed server
 * @internal
 */
func hotspotFromRow(row as map of string to string) {
    return HotspotServer{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        interfaceName: rowValue($row, "interface"),
        addressPool: rowValue($row, "address-pool"),
        profile: rowValue($row, "profile"),
        disabled: rowBool($row, "disabled")
    };
}

/**
 * Fold a reply row into a HotspotUser.
 *
 * @param {map of string to string} row an "/ip/hotspot/user/print" row
 * @return {HotspotUser} the typed user
 * @internal
 */
func hotspotUserFromRow(row as map of string to string) {
    return HotspotUser{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        profile: rowValue($row, "profile"),
        limitUptime: rowValue($row, "limit-uptime"),
        uptime: rowValue($row, "uptime"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * Fold a reply row into a HotspotSession.
 *
 * @param {map of string to string} row an "/ip/hotspot/active/print" row
 * @return {HotspotSession} the typed session
 * @internal
 */
func hotspotSessionFromRow(row as map of string to string) {
    return HotspotSession{
        user: rowValue($row, "user"),
        address: rowValue($row, "address"),
        mac: rowValue($row, "mac-address"),
        uptime: rowValue($row, "uptime"),
        idleTime: rowValue($row, "idle-time"),
        bytesIn: rowInt($row, "bytes-in"),
        bytesOut: rowInt($row, "bytes-out")
    };
}
