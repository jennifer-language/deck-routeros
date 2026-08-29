# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - VLAN tagged interfaces.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the VLAN interface list. */
export def const VLAN_PATH as string init "/interface/vlan";

/**
 * One VLAN interface: a tagged virtual interface on top of a parent.
 *
 * Traffic through it carries the VLAN tag, so several separate networks
 * can share one physical cable or bridge.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} name          interface name (e.g. "vlanoffice")
 * @field {int}    vlanId        the 802.1Q tag, 1-4094
 * @field {string} interfaceName parent interface the VLAN rides on
 * @field {string} mtu           MTU as reported
 * @field {bool}   running       true when the parent is up
 * @field {bool}   disabled      true when the VLAN is switched off
 * @field {string} comment       free-text comment, "" when unset
 */
export def struct Vlan {
    id as string,
    name as string,
    vlanId as int,
    interfaceName as string,
    mtu as string,
    running as bool,
    disabled as bool,
    comment as string
};

/**
 * List every VLAN interface on the router.
 *
 * @param {Client} c an open client
 * @return {list of Vlan} all VLAN interfaces
 */
export func vlans(c as Client) {
    def rows as list of map of string to string init getAll($c, VLAN_PATH);
    def out as list of Vlan init [];
    for (def row in $rows) {
        $out[] = vlanFromRow($row);
    }
    return $out;
}

/**
 * Look one VLAN interface up by its name.
 *
 * @param {Client} c    an open client
 * @param {string} name VLAN interface name
 * @return {Vlan} the VLAN
 * @throws {Error} kind "routeros" when no VLAN has that name
 */
export func vlanByName(c as Client, name as string) {
    def row as map of string to string init findByName($c, VLAN_PATH, $name);
    if (len($row) == 0) {
        raiseError("the VLAN \"" + $name + "\" was not found on the router");
    }
    return vlanFromRow($row);
}

/**
 * Create a VLAN interface: a tagged network on top of an existing one.
 *
 * Traffic on the new interface carries 802.1Q tag `vlanId`, so several
 * networks can share the parent's cable - the device on the other end
 * (a managed switch or another router) must have the same VLAN id
 * configured. The VLAN interface then behaves like any other interface:
 * give it an address (`addIpAddress`), serve DHCP on it (`setupDhcp`),
 * or put it in a bridge.
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the new interface (e.g. "vlanoffice")
 * @param {int}    vlanId        the 802.1Q tag, 1-4094 (both ends must match)
 * @param {string} interfaceName parent interface to ride on (e.g. "ether2", a bridge)
 * @return {string} the RouterOS id of the new VLAN interface
 * @throws {Error} kind "routeros" on a bad name, an id outside 1-4094,
 *                 or an unknown parent interface
 * @example
 *   mt.addVlan($c, "vlanoffice", 20, "ether2");
 *   mt.addIpAddress($c, "10.20.0.1/24", "vlanoffice");
 */
export func addVlan(c as Client, name as string, vlanId as int, interfaceName as string) {
    ensureName($name, "VLAN");
    ensureVlanId($vlanId);
    requiredId($c, INTERFACE_PATH, $interfaceName, "interface");
    return add(
        $c,
        VLAN_PATH,
        {"name": $name, "vlan-id": convert.toString($vlanId), "interface": $interfaceName});
}

/**
 * Delete a VLAN interface by name.
 *
 * @param {Client} c    an open client
 * @param {string} name the VLAN interface name
 * @throws {Error} kind "routeros" when no VLAN has that name
 */
export func removeVlan(c as Client, name as string) {
    remove($c, VLAN_PATH, requiredId($c, VLAN_PATH, $name, "VLAN"));
}

/**
 * Switch a VLAN interface on.
 *
 * @param {Client} c    an open client
 * @param {string} name the VLAN interface name
 * @throws {Error} kind "routeros" when no VLAN has that name
 */
export func enableVlan(c as Client, name as string) {
    enable($c, VLAN_PATH, requiredId($c, VLAN_PATH, $name, "VLAN"));
}

/**
 * Switch a VLAN interface off.
 *
 * @param {Client} c    an open client
 * @param {string} name the VLAN interface name
 * @throws {Error} kind "routeros" when no VLAN has that name
 */
export func disableVlan(c as Client, name as string) {
    disable($c, VLAN_PATH, requiredId($c, VLAN_PATH, $name, "VLAN"));
}

/**
 * Validate an 802.1Q VLAN id.
 *
 * @param {int} vlanId the candidate id
 * @throws {Error} kind "routeros" when outside 1-4094
 * @internal
 */
func ensureVlanId(vlanId as int) {
    if ($vlanId < 1 or $vlanId > 4094) {
        raiseError("the VLAN id must be between 1 and 4094");
    }
}

/**
 * Fold a reply row into a Vlan.
 *
 * @param {map of string to string} row an "/interface/vlan/print" row
 * @return {Vlan} the typed VLAN interface
 * @internal
 */
func vlanFromRow(row as map of string to string) {
    return Vlan{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        vlanId: rowInt($row, "vlan-id"),
        interfaceName: rowValue($row, "interface"),
        mtu: rowValue($row, "mtu"),
        running: rowBool($row, "running"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
