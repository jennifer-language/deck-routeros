# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - bonding: several ethernet links acting as one.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the bonding interface list. */
export def const BONDING_PATH as string init "/interface/bonding";

/** Bond mode for LACP (802.3ad) aggregation with a managed switch. */
export def const BOND_LACP as string init "802.3ad";

/** Bond mode for plain failover: one active link, the rest stand by. */
export def const BOND_ACTIVE_BACKUP as string init "active-backup";

def const BONDING_MODES as list of string init [
    "balance-rr",
    "active-backup",
    "balance-xor",
    "broadcast",
    "802.3ad",
    "balance-tlb",
    "balance-alb"
];

/**
 * One bonding interface: several physical links acting as one.
 *
 * @field {string} id                 internal RouterOS id
 * @field {string} name               bond name (e.g. "bondtrunk")
 * @field {string} slaves             member interfaces, comma-separated
 * @field {string} mode               bonding mode ("802.3ad", "active-backup", ...)
 * @field {string} primary            preferred link in active-backup mode, "" otherwise
 * @field {string} transmitHashPolicy how 802.3ad spreads flows, "" when default
 * @field {string} mac                the bond's MAC address
 * @field {string} mtu                MTU as reported
 * @field {bool}   running            true when at least one member link is up
 * @field {bool}   disabled           true when the bond is switched off
 * @field {string} comment            free-text comment, "" when unset
 */
export def struct Bond {
    id as string,
    name as string,
    slaves as string,
    mode as string,
    primary as string,
    transmitHashPolicy as string,
    mac as string,
    mtu as string,
    running as bool,
    disabled as bool,
    comment as string
};

/**
 * List every bonding interface on the router.
 *
 * @param {Client} c an open client
 * @return {list of Bond} all bonds
 */
export func bonds(c as Client) {
    def rows as list of map of string to string init getAll($c, BONDING_PATH);
    def out as list of Bond init [];
    for (def row in $rows) {
        $out[] = bondFromRow($row);
    }
    return $out;
}

/**
 * Look one bond up by its name.
 *
 * @param {Client} c    an open client
 * @param {string} name the bond's name
 * @return {Bond} the bond
 * @throws {Error} kind "routeros" when no bond has that name
 */
export func bondByName(c as Client, name as string) {
    def row as map of string to string init findByName($c, BONDING_PATH, $name);
    if (len($row) == 0) {
        raiseError("the bond \"" + $name + "\" was not found on the router");
    }
    return bondFromRow($row);
}

/**
 * Create a bond in an explicit mode.
 *
 * Prefer the two shaped helpers - `addLacpBond` for throughput with a
 * managed switch, `addFailoverBond` for plain redundancy - and reach
 * for this one only when you need another mode. At least two member
 * interfaces are required (one link is not a bond), each must exist,
 * and none may already serve another bond. The bond then behaves like
 * any interface: bridge it, address it, VLAN it.
 *
 * @param {Client} c      an open client
 * @param {string} name   name for the bond (e.g. "bondtrunk")
 * @param {string} slaves member interfaces, comma-separated (e.g. "ether1,ether2")
 * @param {string} mode   one of balance-rr, active-backup, balance-xor,
 *                        broadcast, 802.3ad, balance-tlb, balance-alb
 * @return {string} the RouterOS id of the new bond
 * @throws {Error} kind "routeros" on a bad name, mode, or slave list
 */
export func addBond(c as Client, name as string, slaves as string, mode as string) {
    ensureName($name, "bond");
    ensureBondMode($mode);
    def members as string init normalizedSlaves($slaves);
    ensureSlavesFree($c, $members, "");
    return add($c, BONDING_PATH, {"name": $name, "slaves": $members, "mode": $mode});
}

/**
 * Aggregate links for throughput and redundancy with LACP (802.3ad).
 *
 * The other end must be a managed switch (or router) with a matching
 * LACP link-aggregation group on those ports - LACP negotiates the
 * bundle, so a mismatch fails visibly instead of looping. Note that
 * one *flow* still uses one link; aggregation raises total capacity,
 * not single-transfer speed (spread flows better via
 * transmit-hash-policy with the generic `set`).
 *
 * @param {Client} c      an open client
 * @param {string} name   name for the bond
 * @param {string} slaves member interfaces, comma-separated
 * @return {string} the RouterOS id of the new bond
 * @throws {Error} kind "routeros" on a bad name or slave list
 * @example
 *   mt.addLacpBond($c, "bondtrunk", "ether1,ether2");
 *   mt.addBridgePort($c, "brlan", "bondtrunk");
 */
export func addLacpBond(c as Client, name as string, slaves as string) {
    return addBond($c, $name, $slaves, BOND_LACP);
}

/**
 * Bundle links for pure failover (active-backup).
 *
 * One link carries the traffic; the others take over when it dies.
 * Works with ANY switch (no LACP needed), which makes it the safe
 * choice for redundancy across two independent switches.
 *
 * @param {Client} c       an open client
 * @param {string} name    name for the bond
 * @param {string} slaves  member interfaces, comma-separated
 * @param {string} primary the preferred link (must be one of the slaves)
 * @return {string} the RouterOS id of the new bond
 * @throws {Error} kind "routeros" on a bad name or slave list, or a
 *                 primary that is not a member
 * @example
 *   mt.addFailoverBond($c, "bonduplink", "ether1,ether2", "ether1");
 */
export func addFailoverBond(c as Client, name as string, slaves as string, primary as string) {
    ensureName($name, "bond");
    def members as string init normalizedSlaves($slaves);
    ensurePrimaryInSlaves($members, $primary);
    ensureSlavesFree($c, $members, "");
    return add(
        $c,
        BONDING_PATH,
        {"name": $name, "slaves": $members, "mode": BOND_ACTIVE_BACKUP, "primary": $primary});
}

/**
 * Change which interfaces a bond is made of.
 *
 * The same checks as on creation apply; the bond's own current members
 * do not count as "already in use".
 *
 * @param {Client} c      an open client
 * @param {string} name   the bond's name
 * @param {string} slaves the new member list, comma-separated
 * @throws {Error} kind "routeros" on an unknown bond or a bad slave list
 */
export func setBondSlaves(c as Client, name as string, slaves as string) {
    def id as string init requiredId($c, BONDING_PATH, $name, "bond");
    def members as string init normalizedSlaves($slaves);
    ensureSlavesFree($c, $members, $name);
    set($c, BONDING_PATH, $id, {"slaves": $members});
}

/**
 * Delete a bond; its member interfaces become ordinary ports again.
 *
 * Anything that referenced the bond (bridge port, addresses) loses its
 * interface - tear those down first.
 *
 * @param {Client} c    an open client
 * @param {string} name the bond's name
 * @throws {Error} kind "routeros" when no bond has that name
 */
export func removeBond(c as Client, name as string) {
    remove($c, BONDING_PATH, requiredId($c, BONDING_PATH, $name, "bond"));
}

/**
 * Switch a bond on.
 *
 * @param {Client} c    an open client
 * @param {string} name the bond's name
 * @throws {Error} kind "routeros" when no bond has that name
 */
export func enableBond(c as Client, name as string) {
    enable($c, BONDING_PATH, requiredId($c, BONDING_PATH, $name, "bond"));
}

/**
 * Switch a bond off; all its links stop carrying traffic.
 *
 * @param {Client} c    an open client
 * @param {string} name the bond's name
 * @throws {Error} kind "routeros" when no bond has that name
 */
export func disableBond(c as Client, name as string) {
    disable($c, BONDING_PATH, requiredId($c, BONDING_PATH, $name, "bond"));
}

/**
 * Validate a bonding mode.
 *
 * @param {string} mode the candidate
 * @throws {Error} kind "routeros" on an unknown mode
 * @internal
 */
func ensureBondMode(mode as string) {
    if (not lists.contains(BONDING_MODES, $mode)) {
        raiseError("unknown bonding mode \"" + $mode + "\" - use one of: " +
            strings.join(BONDING_MODES, ", "));
    }
}

/**
 * Validate and normalize a slave list: at least two distinct,
 * space-free interface names.
 *
 * @param {string} csv the candidate list
 * @return {string} the normalized list
 * @throws {Error} kind "routeros" on fewer than two members, an empty
 *                 entry, a spaced name, or a duplicate
 * @internal
 */
func normalizedSlaves(csv as string) {
    def parts as list of string init strings.split($csv, ",");
    def out as list of string init [];
    for (def part in $parts) {
        def p as string init strings.trim($part);
        if ($p == "") {
            raiseError("the slave list \"" + $csv + "\" must not contain empty entries");
        }
        ensureName($p, "slave interface");
        if (lists.contains($out, $p)) {
            raiseError("the slave \"" + $p + "\" is listed twice");
        }
        $out[] = $p;
    }
    if (len($out) < 2) {
        raiseError("a bond needs at least two member interfaces - one link is not a bond");
    }
    return strings.join($out, ",");
}

/**
 * Test whether a bond's slave list contains an interface.
 *
 * @param {string} slavesCsv the bond's "slaves" value
 * @param {string} name      the interface to look for (exact)
 * @return {bool} true when present
 * @internal
 */
func bondHasSlave(slavesCsv as string, name as string) {
    def parts as list of string init strings.split($slavesCsv, ",");
    for (def part in $parts) {
        if (strings.trim($part) == $name) {
            return true;
        }
    }
    return false;
}

/**
 * Which bond (if any) already uses an interface as a slave?
 *
 * @param {list of map of string to string} rows "/interface/bonding/print" rows
 * @param {string} name the interface to look for
 * @return {string} the bond's name, or "" when the interface is free
 * @internal
 */
func bondUsingSlave(rows as list of map of string to string, name as string) {
    for (def row in $rows) {
        if (bondHasSlave(rowValue($row, "slaves"), $name)) {
            return rowValue($row, "name");
        }
    }
    return "";
}

/**
 * Require the primary of a failover bond to be one of its slaves.
 *
 * @param {string} slavesCsv the normalized slave list
 * @param {string} primary   the candidate primary
 * @throws {Error} kind "routeros" when the primary is not a member
 * @internal
 */
func ensurePrimaryInSlaves(slavesCsv as string, primary as string) {
    if (not bondHasSlave($slavesCsv, $primary)) {
        raiseError("the primary \"" + $primary + "\" must be one of the bond's slaves (" +
            $slavesCsv + ")");
    }
}

/**
 * Verify every member exists and serves no other bond.
 *
 * @param {Client} c          an open client
 * @param {string} membersCsv the normalized slave list
 * @param {string} ownBond    bond name whose current membership does not
 *                            count as "in use" ("" on creation)
 * @throws {Error} kind "routeros" on an unknown interface or one that
 *                 already serves another bond
 * @internal
 */
func ensureSlavesFree(c as Client, membersCsv as string, ownBond as string) {
    def rows as list of map of string to string init getAll($c, BONDING_PATH);
    def ifaceRows as list of map of string to string init getAll($c, INTERFACE_PATH);
    def parts as list of string init strings.split($membersCsv, ",");
    for (def part in $parts) {
        if (len(findRowByField($ifaceRows, "name", $part)) == 0) {
            raiseError("the slave interface \"" + $part + "\" was not found on the router");
        }
        def owner as string init bondUsingSlave($rows, $part);
        if ($owner != "" and $owner != $ownBond) {
            raiseError("the interface \"" + $part + "\" already serves the bond \"" + $owner + "\"");
        }
    }
}

/**
 * Fold a reply row into a Bond.
 *
 * @param {map of string to string} row an "/interface/bonding/print" row
 * @return {Bond} the typed bond
 * @internal
 */
func bondFromRow(row as map of string to string) {
    return Bond{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        slaves: rowValue($row, "slaves"),
        mode: rowValue($row, "mode"),
        primary: rowValue($row, "primary"),
        transmitHashPolicy: rowValue($row, "transmit-hash-policy"),
        mac: rowValue($row, "mac-address"),
        mtu: rowValue($row, "mtu"),
        running: rowBool($row, "running"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
