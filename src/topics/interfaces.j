# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - network interfaces.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the interface list. */
export def const INTERFACE_PATH as string init "/interface";

/**
 * One network interface as reported by the router.
 *
 * @field {string} id       internal RouterOS id (e.g. "*1")
 * @field {string} name     interface name (e.g. "ether1")
 * @field {string} kind     interface type (e.g. "ether", "bridge", "wlan")
 * @field {string} mac      hardware MAC address, "" when the router reports none
 * @field {bool}   running  true when the link is up and passing traffic
 * @field {bool}   disabled true when the interface is administratively off
 * @field {string} comment  free-text comment, "" when unset
 */
export def struct Interface {
    id as string,
    name as string,
    kind as string,
    mac as string,
    running as bool,
    disabled as bool,
    comment as string
};

/**
 * List every network interface on the router.
 *
 * @param {Client} c an open client
 * @return {list of Interface} all interfaces, physical and virtual
 */
export func interfaces(c as Client) {
    def rows as list of map of string to string init getAll($c, INTERFACE_PATH);
    def out as list of Interface init [];
    for (def row in $rows) {
        $out[] = interfaceFromRow($row);
    }
    return $out;
}

/**
 * Look one interface up by its name.
 *
 * @param {Client} c    an open client
 * @param {string} name interface name (e.g. "ether1")
 * @return {Interface} the interface
 * @throws {Error} kind "routeros" when no interface has that name
 */
export func interfaceByName(c as Client, name as string) {
    def row as map of string to string init findByName($c, INTERFACE_PATH, $name);
    if (len($row) == 0) {
        raiseError("interface \"" + $name + "\" was not found");
    }
    return interfaceFromRow($row);
}

/**
 * Switch an interface on.
 *
 * @param {Client} c    an open client
 * @param {string} name interface name
 * @throws {Error} kind "routeros" when no interface has that name
 */
export func enableInterface(c as Client, name as string) {
    enable($c, INTERFACE_PATH, requiredId($c, INTERFACE_PATH, $name, "interface"));
}

/**
 * Switch an interface off.
 *
 * Traffic stops flowing through it until it is enabled again.
 *
 * @param {Client} c    an open client
 * @param {string} name interface name
 * @throws {Error} kind "routeros" when no interface has that name
 */
export func disableInterface(c as Client, name as string) {
    disable($c, INTERFACE_PATH, requiredId($c, INTERFACE_PATH, $name, "interface"));
}

/**
 * Give an interface a new name.
 *
 * @param {Client} c       an open client
 * @param {string} current the name the interface has now
 * @param {string} next    the name it should have
 * @throws {Error} kind "routeros" on a bad new name or an unknown interface
 */
export func renameInterface(c as Client, current as string, next as string) {
    ensureName($next, "interface");
    set($c, INTERFACE_PATH, requiredId($c, INTERFACE_PATH, $current, "interface"), {"name": $next});
}

/**
 * Attach a free-text comment to an interface.
 *
 * @param {Client} c       an open client
 * @param {string} name    interface name
 * @param {string} comment the comment to store ("" clears it)
 * @throws {Error} kind "routeros" when no interface has that name
 */
export func commentInterface(c as Client, name as string, comment as string) {
    set(
        $c,
        INTERFACE_PATH,
        requiredId($c, INTERFACE_PATH, $name, "interface"),
        {"comment": $comment});
}

/**
 * Fold a reply row into an Interface.
 *
 * @param {map of string to string} row a "/interface/print" row
 * @return {Interface} the typed interface
 * @internal
 */
func interfaceFromRow(row as map of string to string) {
    return Interface{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        kind: rowValue($row, "type"),
        mac: rowValue($row, "mac-address"),
        running: rowBool($row, "running"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
