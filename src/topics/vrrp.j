# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - VRRP: two routers, one gateway address, automatic failover.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the VRRP interface list. */
export def const VRRP_PATH as string init "/interface/vrrp";

/**
 * One VRRP instance: this router's share of a redundant gateway.
 *
 * Two (or more) routers with the same `vrid` on the same network guard
 * one virtual address together; the highest priority is master and
 * answers for it, the others stand by.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} name          VRRP interface name (e.g. "vrrplan")
 * @field {string} interfaceName underlying interface (the shared network)
 * @field {int}    vrid          virtual router id, 1-255 - same on all peers
 * @field {int}    priority      1-254, highest becomes master
 * @field {string} interval      advertisement interval as reported
 * @field {int}    version       VRRP protocol version (2 or 3)
 * @field {bool}   preemption    true when a returning higher priority takes over
 * @field {bool}   running       true when the instance is active
 * @field {bool}   backup        true while standing by
 * @field {bool}   master        computed: running and not backup - this
 *                               router currently answers for the address
 * @field {bool}   disabled      true when the instance is switched off
 * @field {string} comment       free-text comment, "" when unset
 */
export def struct VrrpInterface {
    id as string,
    name as string,
    interfaceName as string,
    vrid as int,
    priority as int,
    interval as string,
    version as int,
    preemption as bool,
    running as bool,
    backup as bool,
    master as bool,
    disabled as bool,
    comment as string
};

/**
 * List every VRRP instance on the router.
 *
 * @param {Client} c an open client
 * @return {list of VrrpInterface} all instances, with master/backup state
 */
export func vrrpInterfaces(c as Client) {
    def rows as list of map of string to string init getAll($c, VRRP_PATH);
    def out as list of VrrpInterface init [];
    for (def row in $rows) {
        $out[] = vrrpFromRow($row);
    }
    return $out;
}

/**
 * Look one VRRP instance up by its name.
 *
 * The quick health question is `.master`: is this router currently the
 * one answering for the shared address?
 *
 * @param {Client} c    an open client
 * @param {string} name the VRRP interface name
 * @return {VrrpInterface} the instance
 * @throws {Error} kind "routeros" when no VRRP interface has that name
 */
export func vrrpByName(c as Client, name as string) {
    def row as map of string to string init findByName($c, VRRP_PATH, $name);
    if (len($row) == 0) {
        raiseError("the VRRP interface \"" + $name + "\" was not found on the router");
    }
    return vrrpFromRow($row);
}

/**
 * Make this router one half of a redundant gateway, in one call.
 *
 * Creates the VRRP instance on the LAN interface and puts the shared
 * virtual address on it. Run the same call on the OTHER router with
 * the same `vrid` and `virtualAddress` but a DIFFERENT priority -
 * higher wins, so give the preferred router e.g. 200 and the standby
 * 100. Clients then use the virtual address as their gateway; when the
 * master dies, the standby answers within seconds and nobody
 * reconfigures anything.
 *
 * @param {Client} c              an open client
 * @param {string} name           name for the VRRP interface (e.g. "vrrplan")
 * @param {string} interfaceName  the shared network's interface (e.g. "brlan")
 * @param {int}    vrid           virtual router id, 1-255 - identical on all peers
 * @param {int}    priority       1-254; the highest priority becomes master
 * @param {string} virtualAddress the shared gateway address with prefix,
 *                                "/32" by convention (e.g. "192.168.88.254/32")
 * @return {string} the RouterOS id of the VRRP interface
 * @throws {Error} kind "routeros" on bad input, a taken name, or a
 *                 vrid already used on that interface
 * @example
 *   # router A (preferred):
 *   mt.setupVrrp($c, "vrrplan", "brlan", 10, 200, "192.168.88.254/32");
 *   # router B (standby): same vrid + address, lower priority
 *   # mt.setupVrrp($cb, "vrrplan", "brlan", 10, 100, "192.168.88.254/32");
 */
export func setupVrrp(c as Client, name as string, interfaceName as string, vrid as int, priority as int, virtualAddress as string) {
    ensureCidr($virtualAddress);
    def id as string init addVrrp($c, $name, $interfaceName, $vrid, $priority);
    add($c, IP_ADDRESS_PATH, {"address": $virtualAddress, "interface": $name});
    return $id;
}

/**
 * Create a VRRP instance without an address (the primitive).
 *
 * Use `setupVrrp` unless you attach the address yourself.
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the VRRP interface
 * @param {string} interfaceName the underlying interface
 * @param {int}    vrid          virtual router id, 1-255
 * @param {int}    priority      1-254; highest becomes master
 * @return {string} the RouterOS id of the new instance
 * @throws {Error} kind "routeros" on bad input, a taken name, or a
 *                 vrid already used on that interface
 */
export func addVrrp(c as Client, name as string, interfaceName as string, vrid as int, priority as int) {
    ensureName($name, "VRRP interface");
    ensureVrid($vrid);
    ensureVrrpPriority($priority);
    requiredId($c, INTERFACE_PATH, $interfaceName, "interface");
    if (idByName($c, VRRP_PATH, $name) != "") {
        raiseError("the VRRP interface \"" + $name + "\" already exists");
    }
    def rows as list of map of string to string init getAll($c, VRRP_PATH);
    def clash as map of string to string init findVrrpRow($rows, $interfaceName, $vrid);
    if (len($clash) > 0) {
        raiseError("vrid " + convert.toString($vrid) + " on \"" + $interfaceName
            + "\" is already used by \"" + rowValue($clash, "name") + "\"");
    }
    return add($c, VRRP_PATH, {
        "name": $name,
        "interface": $interfaceName,
        "vrid": convert.toString($vrid),
        "priority": convert.toString($priority)
    });
}

/**
 * Change a VRRP instance's priority.
 *
 * The failover dial: raise it to make this router take over (with
 * preemption on), lower it to hand the role away gracefully - e.g.
 * before maintenance.
 *
 * @param {Client} c        an open client
 * @param {string} name     the VRRP interface name
 * @param {int}    priority the new priority, 1-254
 * @throws {Error} kind "routeros" on an unknown instance or a priority
 *                 outside 1-254
 */
export func setVrrpPriority(c as Client, name as string, priority as int) {
    ensureVrrpPriority($priority);
    set($c, VRRP_PATH, requiredId($c, VRRP_PATH, $name, "VRRP interface"),
        {"priority": convert.toString($priority)});
}

/**
 * Delete a VRRP instance and the virtual address(es) sitting on it.
 *
 * The peer router (if any) takes over the shared address - removing
 * one half of a redundant pair is safe for the clients.
 *
 * @param {Client} c    an open client
 * @param {string} name the VRRP interface name
 * @throws {Error} kind "routeros" when no VRRP interface has that name
 */
export func removeVrrp(c as Client, name as string) {
    def id as string init requiredId($c, VRRP_PATH, $name, "VRRP interface");
    def addrRows as list of map of string to string init getAll($c, IP_ADDRESS_PATH);
    for (def row in $addrRows) {
        if (rowValue($row, "interface") == $name and not rowBool($row, "dynamic")) {
            remove($c, IP_ADDRESS_PATH, rowValue($row, ".id"));
        }
    }
    remove($c, VRRP_PATH, $id);
}

/**
 * Switch a VRRP instance on.
 *
 * @param {Client} c    an open client
 * @param {string} name the VRRP interface name
 * @throws {Error} kind "routeros" when no VRRP interface has that name
 */
export func enableVrrp(c as Client, name as string) {
    enable($c, VRRP_PATH, requiredId($c, VRRP_PATH, $name, "VRRP interface"));
}

/**
 * Switch a VRRP instance off; the peer takes over the shared address.
 *
 * @param {Client} c    an open client
 * @param {string} name the VRRP interface name
 * @throws {Error} kind "routeros" when no VRRP interface has that name
 */
export func disableVrrp(c as Client, name as string) {
    disable($c, VRRP_PATH, requiredId($c, VRRP_PATH, $name, "VRRP interface"));
}

/**
 * Validate a virtual router id.
 *
 * @param {int} vrid the candidate id
 * @throws {Error} kind "routeros" when outside 1-255
 * @internal
 */
func ensureVrid(vrid as int) {
    if ($vrid < 1 or $vrid > 255) {
        raiseError("the vrid must be between 1 and 255 (and identical on all peers)");
    }
}

/**
 * Validate a VRRP priority.
 *
 * @param {int} priority the candidate priority
 * @throws {Error} kind "routeros" when outside 1-254 (255 is reserved
 *                 for the address owner per the RFC)
 * @internal
 */
func ensureVrrpPriority(priority as int) {
    if ($priority < 1 or $priority > 254) {
        raiseError("the priority must be between 1 and 254 - the highest peer becomes master");
    }
}

/**
 * Find a VRRP instance using a vrid on an interface.
 *
 * The same vrid on DIFFERENT interfaces is fine - the id only has to
 * be unique per network segment.
 *
 * @param {list of map of string to string} rows "/interface/vrrp/print" rows
 * @param {string} interfaceName the underlying interface
 * @param {int}    vrid          the virtual router id
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func findVrrpRow(rows as list of map of string to string, interfaceName as string, vrid as int) {
    for (def row in $rows) {
        if (rowValue($row, "interface") == $interfaceName and rowInt($row, "vrid") == $vrid) {
            return $row;
        }
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Fold a reply row into a VrrpInterface.
 *
 * `master` is computed here: running and not in backup state.
 *
 * @param {map of string to string} row an "/interface/vrrp/print" row
 * @return {VrrpInterface} the typed instance
 * @internal
 */
func vrrpFromRow(row as map of string to string) {
    def running as bool init rowBool($row, "running");
    def backup as bool init rowBool($row, "backup");
    return VrrpInterface{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        interfaceName: rowValue($row, "interface"),
        vrid: rowInt($row, "vrid"),
        priority: rowInt($row, "priority"),
        interval: rowValue($row, "interval"),
        version: rowInt($row, "version"),
        preemption: rowBool($row, "preemption-mode"),
        running: $running,
        backup: $backup,
        master: $running and not $backup,
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
