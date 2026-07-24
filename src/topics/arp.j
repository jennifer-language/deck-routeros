# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - the ARP table: which IP belongs to which MAC.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the ARP table. */
export def const ARP_PATH as string init "/ip/arp";

/**
 * One ARP entry: an IP-to-MAC binding on an interface.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} address       the IP address
 * @field {string} mac           the MAC address it resolves to, "" while unresolved
 * @field {string} interfaceName interface the binding lives on
 * @field {bool}   dynamic       true when the router learned it by itself;
 *                               false for a static (pinned) entry
 * @field {bool}   complete      true when the MAC is actually known
 * @field {bool}   published     true when the router answers ARP for this
 *                               address itself (proxy ARP)
 * @field {bool}   disabled      true when the entry is switched off
 * @field {string} comment       free-text comment, "" when unset
 */
export def struct ArpEntry {
    id as string,
    address as string,
    mac as string,
    interfaceName as string,
    dynamic as bool,
    complete as bool,
    published as bool,
    disabled as bool,
    comment as string
};

/**
 * Read the whole ARP table.
 *
 * Every device the router recently talked to on its connected networks
 * shows up here - it doubles as a "who is on my LAN" list.
 *
 * @param {Client} c an open client
 * @return {list of ArpEntry} all entries, dynamic and static
 */
export func arpTable(c as Client) {
    def rows as list of map of string to string init getAll($c, ARP_PATH);
    def out as list of ArpEntry init [];
    for (def row in $rows) {
        $out[] = arpFromRow($row);
    }
    return $out;
}

/**
 * The ARP entries on one interface.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface (or bridge) to filter for
 * @return {list of ArpEntry} that interface's entries
 */
export func arpTableOn(c as Client, interfaceName as string) {
    def all as list of ArpEntry init arpTable($c);
    def out as list of ArpEntry init [];
    for (def entry in $all) {
        if ($entry.interfaceName == $interfaceName) {
            $out[] = $entry;
        }
    }
    return $out;
}

/**
 * Which MAC address does an IP resolve to right now?
 *
 * A miss is normal (the device may simply be offline or never have
 * talked to the router), so this returns "" instead of throwing.
 *
 * @param {Client} c       an open client
 * @param {string} address the IP address to look up
 * @return {string} the MAC address, or "" when the table has no entry
 * @throws {Error} kind "routeros" on a malformed address
 */
export func macForAddress(c as Client, address as string) {
    def target as string init strings.trim($address);
    ensureIpAddress($target);
    def rows as list of map of string to string init getAll($c, ARP_PATH);
    def row as map of string to string init findRowByField($rows, "address", $target);
    return rowValue($row, "mac-address");
}

/**
 * Which IP addresses does a device (a MAC) currently hold?
 *
 * The reverse lookup - useful for "where did my printer go". A device
 * can legitimately hold several addresses.
 *
 * @param {Client} c   an open client
 * @param {string} mac the device's MAC address (case-insensitive)
 * @return {list of string} its IP addresses, possibly empty
 * @throws {Error} kind "routeros" on a malformed MAC
 */
export func addressesForMac(c as Client, mac as string) {
    ensureMac($mac);
    def rows as list of map of string to string init getAll($c, ARP_PATH);
    return addressesForMacRows($rows, $mac);
}

/**
 * Pin an IP-to-MAC binding (a static ARP entry).
 *
 * The router then never re-learns that address from the network -
 * combined with an interface in `arp=reply-only` mode (generic `set`
 * on INTERFACE_PATH), only pinned devices can talk at all. Refuses to
 * overwrite an existing static entry for the same address.
 *
 * @param {Client} c             an open client
 * @param {string} address       the IP address to pin
 * @param {string} mac           the MAC it must resolve to
 * @param {string} interfaceName interface (or bridge) the binding lives on
 * @return {string} the RouterOS id of the new entry
 * @throws {Error} kind "routeros" on a malformed address or MAC, an
 *                 unknown interface, or an existing static entry
 * @example
 *   mt.addStaticArp($c, "192.168.88.50", "AA:BB:CC:DD:EE:FF", "brlan");
 */
export func addStaticArp(c as Client, address as string, mac as string, interfaceName as string) {
    def target as string init strings.trim($address);
    ensureIpAddress($target);
    ensureMac($mac);
    requiredId($c, INTERFACE_PATH, $interfaceName, "interface");
    def rows as list of map of string to string init getAll($c, ARP_PATH);
    def existing as map of string to string init findStaticArpRow($rows, $target, $interfaceName);
    if (len($existing) > 0) {
        raiseError("a static ARP entry for " + $target + " on \"" + $interfaceName
            + "\" already exists - remove it first (removeArpEntry)");
    }
    return add($c, ARP_PATH, {
        "address": $target,
        "mac-address": strings.upper($mac),
        "interface": $interfaceName
    });
}

/**
 * Remove the ARP entry for an address.
 *
 * Works on static entries (unpin) and on dynamic ones - removing a
 * dynamic entry forces the router to re-resolve, which clears a stale
 * binding after a device swapped hardware.
 *
 * @param {Client} c       an open client
 * @param {string} address the IP address whose entry goes
 * @throws {Error} kind "routeros" when the table has no entry for it
 */
export func removeArpEntry(c as Client, address as string) {
    def target as string init strings.trim($address);
    def rows as list of map of string to string init getAll($c, ARP_PATH);
    def row as map of string to string init findRowByField($rows, "address", $target);
    if (len($row) == 0) {
        raiseError("the ARP table has no entry for \"" + $target + "\"");
    }
    remove($c, ARP_PATH, rowValue($row, ".id"));
}

/**
 * Drop every dynamic ARP entry on an interface.
 *
 * A diagnostic broom: the router re-learns the neighbourhood from
 * scratch. Static entries stay. Doing nothing (no dynamic entries) is
 * fine and not an error.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface to flush
 * @return {int} how many entries were removed
 */
export func flushArp(c as Client, interfaceName as string) {
    def rows as list of map of string to string init getAll($c, ARP_PATH);
    def flushed as int init 0;
    for (def row in $rows) {
        if (rowValue($row, "interface") == $interfaceName and rowBool($row, "dynamic")) {
            remove($c, ARP_PATH, rowValue($row, ".id"));
            $flushed = $flushed + 1;
        }
    }
    return $flushed;
}

/**
 * Collect the addresses rows bound to a MAC, case-insensitively.
 *
 * @param {list of map of string to string} rows "/ip/arp/print" rows
 * @param {string} mac the MAC to match
 * @return {list of string} the bound addresses, in table order
 * @internal
 */
func addressesForMacRows(rows as list of map of string to string, mac as string) {
    def wanted as string init strings.upper(strings.trim($mac));
    def out as list of string init [];
    for (def row in $rows) {
        if (strings.upper(rowValue($row, "mac-address")) == $wanted) {
            $out[] = rowValue($row, "address");
        }
    }
    return $out;
}

/**
 * Find a static (non-dynamic) ARP row for an address on an interface.
 *
 * @param {list of map of string to string} rows "/ip/arp/print" rows
 * @param {string} address       the IP address
 * @param {string} interfaceName the interface
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func findStaticArpRow(rows as list of map of string to string, address as string, interfaceName as string) {
    for (def row in $rows) {
        if (rowValue($row, "address") == $address
                and rowValue($row, "interface") == $interfaceName
                and not rowBool($row, "dynamic")) {
            return $row;
        }
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Fold a reply row into an ArpEntry.
 *
 * @param {map of string to string} row an "/ip/arp/print" row
 * @return {ArpEntry} the typed entry
 * @internal
 */
func arpFromRow(row as map of string to string) {
    return ArpEntry{
        id: rowValue($row, ".id"),
        address: rowValue($row, "address"),
        mac: rowValue($row, "mac-address"),
        interfaceName: rowValue($row, "interface"),
        dynamic: rowBool($row, "dynamic"),
        complete: rowBool($row, "complete"),
        published: rowBool($row, "published"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
