# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - interface lists: named groups of interfaces (WAN/LAN/...).
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the interface lists. */
export def const INTERFACE_LIST_PATH as string init "/interface/list";

/** RouterOS API path of the interface-list members. */
export def const INTERFACE_LIST_MEMBER_PATH as string init "/interface/list/member";

/**
 * One interface list: a named group of interfaces.
 *
 * @field {string} id      internal RouterOS id
 * @field {string} name    the list name (e.g. "WAN", "LAN")
 * @field {bool}   dynamic true when built by the system, not by hand
 * @field {string} comment free-text comment, "" when unset
 */
export def struct InterfaceList {
    id as string,
    name as string,
    dynamic as bool,
    comment as string
};

/**
 * List the interface lists.
 *
 * The built-in lists "all", "none", and "dynamic" always exist.
 *
 * @param {Client} c an open client
 * @return {list of InterfaceList} all lists
 */
export func interfaceLists(c as Client) {
    def rows as list of map of string to string init getAll($c, INTERFACE_LIST_PATH);
    def out as list of InterfaceList init [];
    for (def row in $rows) {
        $out[] = interfaceListFromRow($row);
    }
    return $out;
}

/**
 * Create an interface list.
 *
 * Grouping interfaces as "WAN", "LAN", "MGMT", ... lets firewall rules
 * match a whole group (`withInInterfaceList` / `withOutInterfaceList`) -
 * add or move an interface and every rule follows, no rule edits. This
 * is how the RouterOS v7 default configuration is built. Idempotent by
 * name.
 *
 * @param {Client} c       an open client
 * @param {string} name    the list name (e.g. "WAN")
 * @param {string} comment friendly note ("" for none)
 * @return {string} the RouterOS id of the (new or existing) list
 * @throws {Error} kind "routeros" on an invalid name
 * @example
 *   mt.addInterfaceList($c, "WAN", "internet-facing ports");
 *   mt.addToInterfaceList($c, "WAN", "ether1");
 *   def r as mt.FirewallRule init mt.firewallRule(mt.CHAIN_INPUT, mt.ACTION_DROP);
 *   $r = mt.withInInterfaceList($r, "WAN");
 *   $r = mt.withComment($r, "drop from WAN");
 *   mt.addFirewallRule($c, $r);
 */
export func addInterfaceList(c as Client, name as string, comment as string) {
    ensureName($name, "interface list");
    def existing as string init idByName($c, INTERFACE_LIST_PATH, $name);
    if ($existing != "") {
        return $existing;
    }
    def attrs as map of string to string init {"name": $name};
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, INTERFACE_LIST_PATH, $attrs);
}

/**
 * Delete an interface list (its memberships go with it).
 *
 * @param {Client} c    an open client
 * @param {string} name the list name
 * @throws {Error} kind "routeros" when no list has that name
 */
export func removeInterfaceList(c as Client, name as string) {
    remove($c, INTERFACE_LIST_PATH, requiredId($c, INTERFACE_LIST_PATH, $name, "interface list"));
}

/**
 * The interfaces that are members of a list.
 *
 * @param {Client} c        an open client
 * @param {string} listName the list name
 * @return {list of string} the member interface names, in order
 */
export func interfaceListMembers(c as Client, listName as string) {
    def rows as list of map of string to string init getAll($c, INTERFACE_LIST_MEMBER_PATH);
    def out as list of string init [];
    for (def row in $rows) {
        if (rowValue($row, "list") == $listName) {
            $out[] = rowValue($row, "interface");
        }
    }
    return $out;
}

/**
 * Put an interface into a list.
 *
 * The list is created if it does not exist; the interface must exist.
 * Idempotent - adding a member twice is a no-op.
 *
 * @param {Client} c             an open client
 * @param {string} listName      the list (e.g. "WAN")
 * @param {string} interfaceName the interface to add
 * @return {string} the RouterOS id of the (new or existing) membership
 * @throws {Error} kind "routeros" on a bad list name or unknown interface
 */
export func addToInterfaceList(c as Client, listName as string, interfaceName as string) {
    ensureName($listName, "interface list");
    requiredId($c, INTERFACE_PATH, $interfaceName, "interface");
    if (idByName($c, INTERFACE_LIST_PATH, $listName) == "") {
        add($c, INTERFACE_LIST_PATH, {"name": $listName});
    }
    def rows as list of map of string to string init getAll($c, INTERFACE_LIST_MEMBER_PATH);
    def existing as map of string to string init memberRow($rows, $listName, $interfaceName);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    return add($c, INTERFACE_LIST_MEMBER_PATH, {"list": $listName, "interface": $interfaceName});
}

/**
 * Remove an interface from a list.
 *
 * @param {Client} c             an open client
 * @param {string} listName      the list
 * @param {string} interfaceName the member interface
 * @throws {Error} kind "routeros" when the interface is not in the list
 */
export func removeFromInterfaceList(c as Client, listName as string, interfaceName as string) {
    def rows as list of map of string to string init getAll($c, INTERFACE_LIST_MEMBER_PATH);
    def row as map of string to string init memberRow($rows, $listName, $interfaceName);
    if (len($row) == 0) {
        raiseError("\"" + $interfaceName + "\" is not a member of the interface list \"" +
            $listName + "\"");
    }
    remove($c, INTERFACE_LIST_MEMBER_PATH, rowValue($row, ".id"));
}

/**
 * Find a membership row by list and interface.
 *
 * @param {list of map of string to string} rows member rows
 * @param {string} listName      the list
 * @param {string} interfaceName the interface
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func memberRow(
    rows as list of map of string to string,
    listName as string,
    interfaceName as string) {
    for (def row in $rows) {
        if (rowValue($row, "list") == $listName and rowValue($row, "interface") == $interfaceName) {
            return $row;
        }
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Fold a reply row into an InterfaceList.
 *
 * @param {map of string to string} row an "/interface/list/print" row
 * @return {InterfaceList} the typed list
 * @internal
 */
func interfaceListFromRow(row as map of string to string) {
    return InterfaceList{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        dynamic: rowBool($row, "dynamic"),
        comment: rowValue($row, "comment")
    };
}
