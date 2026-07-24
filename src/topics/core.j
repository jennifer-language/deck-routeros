# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - connection, generic verbs, shared validation and row helpers.
# Spliced into routeros.j via include - not a standalone module.

def const PORT_SPEC_CHARS as string init "0123456789,-";

def const HEX_CHARS as string init "0123456789abcdefABCDEF";

def const DIGIT_CHARS as string init "0123456789";

/**
 * An open, authenticated connection to one router.
 *
 * Obtain one with `connect` / `connectTLS` / `connectWith` and pass it as
 * the first argument to every other call; release it with `disconnect`.
 *
 * @field {mikrotik.Session} session the underlying API session
 * @field {string} user the account this session is logged in as - used
 *        by the user-management helpers to refuse self-destructive
 *        operations (removing or disabling your own account)
 */
export def struct Client { session as mikrotik.Session, user as string };

/**
 * Connect to a router over the plaintext API port (8728).
 *
 * @param {string} host     router address (IP or DNS name)
 * @param {string} user     RouterOS user name
 * @param {string} password RouterOS password
 * @return {Client} an authenticated client
 * @throws {Error} kind "mikrotik" when the connection or login fails
 */
export func connect(host as string, user as string, password as string) {
    return Client{ session: mikrotik.connect(mikrotik.options($host, $user, $password)), user: $user };
}

/**
 * Connect to a router over the TLS API port (8729, api-ssl).
 *
 * @param {string} host     router address (IP or DNS name)
 * @param {string} user     RouterOS user name
 * @param {string} password RouterOS password
 * @return {Client} an authenticated client
 * @throws {Error} kind "mikrotik" when the connection or login fails
 */
export func connectTLS(host as string, user as string, password as string) {
    return Client{ session: mikrotik.connect(mikrotik.optionsTLS($host, $user, $password)), user: $user };
}

/**
 * Connect with an explicit port and TLS choice, for non-default setups.
 *
 * @param {string} host     router address (IP or DNS name)
 * @param {int}    port     API TCP port (e.g. 8728, 8729, or a custom one)
 * @param {string} user     RouterOS user name
 * @param {string} password RouterOS password
 * @param {bool}   tls      true to wrap the connection in TLS
 * @return {Client} an authenticated client
 * @throws {Error} kind "routeros" on an invalid port,
 *                 kind "mikrotik" when the connection or login fails
 */
export func connectWith(host as string, port as int, user as string, password as string, tls as bool) {
    ensurePort($port);
    def o as mikrotik.Options init mikrotik.options($host, $user, $password);
    if ($tls) {
        $o = mikrotik.optionsTLS($host, $user, $password);
    }
    return Client{ session: mikrotik.connect(mikrotik.withPort($o, $port)), user: $user };
}

/**
 * Close the connection behind a client.
 *
 * The client must not be used afterwards.
 *
 * @param {Client} c the client to shut down
 */
export func disconnect(c as Client) {
    mikrotik.close($c.session);
}

/**
 * Read every item under a path.
 *
 * The generic escape hatch for lists routeros has no typed helper for
 * (e.g. "/ip/address", "/ip/dhcp-server/lease").
 *
 * @param {Client} c    an open client
 * @param {string} path RouterOS list path, with or without leading slash
 * @return {list of map of string to string} one property map per item
 * @throws {Error} kind "routeros" on an empty path, kind "mikrotik" on a router error
 */
export func getAll(c as Client, path as string) {
    return mikrotik.print($c.session, apiPath($path));
}

/**
 * Create an item under a path.
 *
 * @param {Client} c     an open client
 * @param {string} path  RouterOS list path (e.g. "/interface/bridge")
 * @param {map of string to string} attrs properties of the new item
 * @return {string} the RouterOS id of the created item
 * @throws {Error} kind "routeros" on an empty path, kind "mikrotik" when the router refuses
 */
export func add(c as Client, path as string, attrs as map of string to string) {
    return mikrotik.run($c.session, apiPath($path) + "/add", $attrs);
}

/**
 * Delete an item by its RouterOS id.
 *
 * `remove` is what RouterOS calls delete; there is no separate delete verb.
 *
 * @param {Client} c    an open client
 * @param {string} path RouterOS list path the item lives under
 * @param {string} id   the item id (e.g. "*3"), as returned by `add` or found in a row
 * @throws {Error} kind "routeros" on an empty path or id, kind "mikrotik" when the router refuses
 */
export func remove(c as Client, path as string, id as string) {
    ensureId($id);
    mikrotik.run($c.session, apiPath($path) + "/remove", {".id": $id});
}

/**
 * Change properties of an existing item.
 *
 * @param {Client} c     an open client
 * @param {string} path  RouterOS list path the item lives under
 * @param {string} id    the item id (e.g. "*3")
 * @param {map of string to string} attrs the properties to change
 * @throws {Error} kind "routeros" on an empty path or id, kind "mikrotik" when the router refuses
 */
export func set(c as Client, path as string, id as string, attrs as map of string to string) {
    ensureId($id);
    def merged as map of string to string init $attrs;
    $merged[".id"] = $id;
    mikrotik.run($c.session, apiPath($path) + "/set", $merged);
}

/**
 * Change properties of an existing item; synonym of `set`.
 *
 * @param {Client} c     an open client
 * @param {string} path  RouterOS list path the item lives under
 * @param {string} id    the item id
 * @param {map of string to string} attrs the properties to change
 * @throws {Error} kind "routeros" on an empty path or id, kind "mikrotik" when the router refuses
 */
export func update(c as Client, path as string, id as string, attrs as map of string to string) {
    set($c, $path, $id, $attrs);
}

/**
 * Find the first item under a path whose "name" property matches.
 *
 * @param {Client} c    an open client
 * @param {string} path RouterOS list path
 * @param {string} name the value of the "name" property to look for
 * @return {map of string to string} the item's properties, or an empty map when absent
 */
export func findByName(c as Client, path as string, name as string) {
    def rows as list of map of string to string init getAll($c, $path);
    return findRowByField($rows, "name", $name);
}

/**
 * Resolve a name to a RouterOS id under a path.
 *
 * @param {Client} c    an open client
 * @param {string} path RouterOS list path
 * @param {string} name the value of the "name" property to look for
 * @return {string} the item id, or "" when no item has that name
 */
export func idByName(c as Client, path as string, name as string) {
    def row as map of string to string init findByName($c, $path, $name);
    return rowValue($row, ".id");
}

/**
 * Delete the item under a path whose "name" property matches.
 *
 * @param {Client} c    an open client
 * @param {string} path RouterOS list path
 * @param {string} name the name of the item to delete
 * @throws {Error} kind "routeros" when no item has that name
 */
export func removeByName(c as Client, path as string, name as string) {
    remove($c, $path, requiredId($c, $path, $name, "item"));
}

/**
 * Switch an item on (clear its disabled flag).
 *
 * @param {Client} c    an open client
 * @param {string} path RouterOS list path
 * @param {string} id   the item id
 */
export func enable(c as Client, path as string, id as string) {
    set($c, $path, $id, {"disabled": "no"});
}

/**
 * Switch an item off (set its disabled flag).
 *
 * The item is kept but stops having any effect until enabled again.
 *
 * @param {Client} c    an open client
 * @param {string} path RouterOS list path
 * @param {string} id   the item id
 */
export func disable(c as Client, path as string, id as string) {
    set($c, $path, $id, {"disabled": "yes"});
}

/**
 * Throw the module's error.
 *
 * @param {string} message human-readable failure description
 * @throws {Error} always, kind "routeros"
 * @internal
 */
func raiseError(message as string) {
    throw Error{ kind: "routeros", message: $message, file: "", line: 0, col: 0 };
}

/**
 * Normalize a RouterOS API path: trim, force a leading slash, strip
 * trailing slashes.
 *
 * @param {string} path raw path (e.g. "interface/bridge/")
 * @return {string} the normalized path (e.g. "/interface/bridge")
 * @throws {Error} kind "routeros" on an empty or root-only path
 * @internal
 */
func apiPath(path as string) {
    def p as string init strings.trim($path);
    if ($p == "") {
        raiseError("the API path must not be empty");
    }
    if (not strings.startsWith($p, "/")) {
        $p = "/" + $p;
    }
    while (strings.endsWith($p, "/") and len($p) > 1) {
        $p = $p[..len($p) - 1];
    }
    if ($p == "/") {
        raiseError("the API path must name a list, not the root");
    }
    return $p;
}

/**
 * Render a bool the way RouterOS expects it in attributes.
 *
 * @param {bool} value the flag
 * @return {string} "yes" or "no"
 * @internal
 */
func boolWord(value as bool) {
    if ($value) {
        return "yes";
    }
    return "no";
}

/**
 * Read a property from a reply row, "" when absent.
 *
 * @param {map of string to string} row a reply row
 * @param {string} key property name
 * @return {string} the value or ""
 * @internal
 */
func rowValue(row as map of string to string, key as string) {
    if (maps.has($row, $key)) {
        return $row[$key];
    }
    return "";
}

/**
 * Read a boolean property from a reply row; absent counts as false.
 *
 * RouterOS renders flags as "true"/"false" (v7) or "yes"/"no" (older);
 * both are accepted.
 *
 * @param {map of string to string} row a reply row
 * @param {string} key property name
 * @return {bool} the flag
 * @internal
 */
func rowBool(row as map of string to string, key as string) {
    def v as string init rowValue($row, $key);
    return $v == "true" or $v == "yes";
}

/**
 * Find the first row whose property `key` equals `value`.
 *
 * @param {list of map of string to string} rows reply rows
 * @param {string} key   property name to compare
 * @param {string} value value to look for
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func findRowByField(rows as list of map of string to string, key as string, value as string) {
    for (def row in $rows) {
        if (rowValue($row, $key) == $value) {
            return $row;
        }
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Resolve a name to an id under a path, throwing a friendly error when absent.
 *
 * @param {Client} c    an open client
 * @param {string} path RouterOS list path
 * @param {string} name the "name" property value to look for
 * @param {string} what noun for the error message (e.g. "bridge")
 * @return {string} the item id
 * @throws {Error} kind "routeros" when no item has that name
 * @internal
 */
func requiredId(c as Client, path as string, name as string, what as string) {
    def id as string init idByName($c, $path, $name);
    if ($id == "") {
        raiseError("the " + $what + " \"" + $name + "\" was not found on the router");
    }
    return $id;
}

/**
 * Validate a non-empty, space-free name.
 *
 * @param {string} name the candidate name
 * @param {string} what noun for the error message
 * @throws {Error} kind "routeros" on an empty or space-containing name
 * @internal
 */
func ensureName(name as string, what as string) {
    if (strings.trim($name) == "") {
        raiseError("the " + $what + " name must not be empty");
    }
    if (strings.contains($name, " ")) {
        raiseError("the " + $what + " name must not contain spaces");
    }
}

/**
 * Validate a RouterOS item id.
 *
 * @param {string} id the candidate id
 * @throws {Error} kind "routeros" on an empty id
 * @internal
 */
func ensureId(id as string) {
    if (strings.trim($id) == "") {
        raiseError("the item id must not be empty");
    }
}

/**
 * Validate a single TCP/UDP port number.
 *
 * @param {int} port the candidate port
 * @throws {Error} kind "routeros" when outside 1-65535
 * @internal
 */
func ensurePort(port as int) {
    if ($port < 1 or $port > 65535) {
        raiseError("the port must be between 1 and 65535");
    }
}

/**
 * Validate a port spec: digits plus "," (list) and "-" (range).
 *
 * @param {string} spec the candidate spec
 * @throws {Error} kind "routeros" on an empty spec or a foreign character
 * @internal
 */
func ensurePortSpec(spec as string) {
    if ($spec == "") {
        raiseError("the port spec must not be empty");
    }
    def parts as list of string init strings.chars($spec);
    for (def ch in $parts) {
        if (not strings.contains(PORT_SPEC_CHARS, $ch)) {
            raiseError("the port spec \"" + $spec + "\" may only contain digits, \",\" and \"-\"");
        }
    }
}

/**
 * Read a single-entry menu (e.g. "/system/resource") as one row.
 *
 * @param {Client} c    an open client
 * @param {string} path RouterOS menu path
 * @return {map of string to string} the first row, or an empty map when
 *         the router sent nothing
 * @internal
 */
func singleRow(c as Client, path as string) {
    def rows as list of map of string to string init getAll($c, $path);
    if (len($rows) > 0) {
        return $rows[0];
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Merge progress rows into one; later rows win on a shared key.
 *
 * Streaming commands like "check-for-updates" report progress as a
 * sequence of partial rows; the final state is their overlay.
 *
 * @param {list of map of string to string} rows the reply rows, in order
 * @return {map of string to string} the merged row
 * @internal
 */
func mergeRows(rows as list of map of string to string) {
    def merged as map of string to string init {};
    for (def row in $rows) {
        def names as list of string init maps.keys($row);
        for (def key in $names) {
            $merged[$key] = $row[$key];
        }
    }
    return $merged;
}

/**
 * Validate one plain IP address (v4 or v6), no prefix.
 *
 * @param {string} address the candidate address
 * @throws {Error} kind "routeros" when it does not parse
 * @internal
 */
func ensureIpAddress(address as string) {
    try {
        ipnet.parseAddress(strings.trim($address));
    } catch (e) {
        raiseError("\"" + $address + "\" is not a valid IP address");
    }
}

/**
 * Validate an address in CIDR form ("address/prefix").
 *
 * @param {string} cidr the candidate (e.g. "192.168.88.0/24")
 * @throws {Error} kind "routeros" on a missing prefix or a parse failure
 * @internal
 */
func ensureCidr(cidr as string) {
    if (not strings.contains($cidr, "/")) {
        raiseError("\"" + $cidr + "\" is missing the prefix length - write it like \"192.168.88.0/24\"");
    }
    try {
        ipnet.parse(strings.trim($cidr));
    } catch (e) {
        raiseError("\"" + $cidr + "\" is not a valid network in CIDR form");
    }
}

/**
 * Require an address to lie inside a network.
 *
 * Call after `ensureCidr` / `ensureIpAddress`, so parse errors have
 * already been reported with better messages.
 *
 * @param {string} cidr    the network (e.g. "192.168.88.0/24")
 * @param {string} address the address that must be inside it
 * @param {string} what    noun for the error message (e.g. "gateway")
 * @throws {Error} kind "routeros" when the address is outside
 * @internal
 */
func ensureInNetwork(cidr as string, address as string, what as string) {
    def net as ipnet.Network init ipnet.parse(strings.trim($cidr));
    def addr as ipnet.Address init ipnet.parseAddress(strings.trim($address));
    if (not ipnet.contains($net, $addr)) {
        raiseError("the " + $what + " " + $address + " is not inside the network " + $cidr);
    }
}

/**
 * Reject a malformed MAC address.
 *
 * @param {string} mac the offending value
 * @throws {Error} always, kind "routeros"
 * @internal
 */
func badMac(mac as string) {
    raiseError("\"" + $mac + "\" is not a MAC address - expected six hex pairs like \"AA:BB:CC:DD:EE:FF\"");
}

/**
 * Validate a MAC address: six colon-separated hex pairs, any case.
 *
 * @param {string} mac the candidate MAC
 * @throws {Error} kind "routeros" on any other shape
 * @internal
 */
func ensureMac(mac as string) {
    def parts as list of string init strings.split($mac, ":");
    if (len($parts) != 6) {
        badMac($mac);
    }
    for (def part in $parts) {
        if (len($part) != 2) {
            badMac($mac);
        }
        def chars as list of string init strings.chars($part);
        for (def ch in $chars) {
            if (not strings.contains(HEX_CHARS, $ch)) {
                badMac($mac);
            }
        }
    }
}

/**
 * Validate and normalize a comma-separated list of IP addresses.
 *
 * @param {string} csv e.g. "1.1.1.1, 9.9.9.9" (spaces tolerated)
 * @return {string} the normalized list, e.g. "1.1.1.1,9.9.9.9"
 * @throws {Error} kind "routeros" on an empty list, an empty entry, or
 *                 an entry that is not an IP address
 * @internal
 */
func normalizedAddressList(csv as string) {
    def parts as list of string init strings.split($csv, ",");
    def out as list of string init [];
    for (def part in $parts) {
        def p as string init strings.trim($part);
        if ($p == "") {
            raiseError("the server list \"" + $csv + "\" must not contain empty entries");
        }
        ensureIpAddress($p);
        $out[] = $p;
    }
    if (len($out) == 0) {
        raiseError("the server list must contain at least one address");
    }
    return strings.join($out, ",");
}

/**
 * Test whether a string is a plain IP address (v4 or v6).
 *
 * @param {string} value the candidate
 * @return {bool} true when it parses as an address
 * @internal
 */
func isIpAddress(value as string) {
    try {
        ipnet.parseAddress(strings.trim($value));
    } catch (e) {
        return false;
    }
    return true;
}

/**
 * Read an integer property from a reply row; absent or unparseable
 * counts as 0.
 *
 * @param {map of string to string} row a reply row
 * @param {string} key property name
 * @return {int} the value or 0
 * @internal
 */
func rowInt(row as map of string to string, key as string) {
    def v as string init rowValue($row, $key);
    if ($v == "") {
        return 0;
    }
    try {
        return convert.toInt($v);
    } catch (e) {
        return 0;
    }
}

/**
 * Validate a ping / bandwidth-test target host.
 *
 * IP addresses and DNS names are both fine (the router resolves), so
 * only the obviously broken is rejected.
 *
 * @param {string} host the candidate (already trimmed)
 * @throws {Error} kind "routeros" on an empty or space-containing host
 * @internal
 */
func ensureHost(host as string) {
    if ($host == "") {
        raiseError("the target host must not be empty");
    }
    if (strings.contains($host, " ")) {
        raiseError("the target host must not contain spaces");
    }
}
