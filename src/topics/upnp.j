# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - UPnP: let LAN devices open their own port forwards.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the UPnP settings. */
export def const UPNP_PATH as string init "/ip/upnp";

/** RouterOS API path of the UPnP per-interface roles. */
export def const UPNP_INTERFACES_PATH as string init "/ip/upnp/interfaces";

def const UPNP_ROLES as list of string init ["internal", "external"];

/**
 * The UPnP service settings.
 *
 * @field {bool} enabled true when UPnP is running
 */
export def struct UpnpSettings {
    enabled as bool
};

/**
 * One interface's UPnP role.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} interfaceName the interface
 * @field {string} role          "internal" (LAN side) or "external" (WAN side)
 * @field {bool}   disabled      true when switched off
 */
export def struct UpnpInterface {
    id as string,
    interfaceName as string,
    role as string,
    disabled as bool
};

/**
 * Read the UPnP settings.
 *
 * @param {Client} c an open client
 * @return {UpnpSettings} the UPnP state
 */
export func upnpStatus(c as Client) {
    return upnpFromRow(singleRow($c, UPNP_PATH));
}

/**
 * List the interfaces' UPnP roles.
 *
 * @param {Client} c an open client
 * @return {list of UpnpInterface} the configured interfaces
 */
export func upnpInterfaces(c as Client) {
    def rows as list of map of string to string init getAll($c, UPNP_INTERFACES_PATH);
    def out as list of UpnpInterface init [];
    for (def row in $rows) {
        $out[] = upnpInterfaceFromRow($row);
    }
    return $out;
}

/**
 * Turn UPnP on.
 *
 * UPnP lets LAN devices (game consoles, some apps) open their own port
 * forwards through the router with no manual rule - convenient, but it
 * means any LAN device can punch a hole to the internet, so weigh it
 * against the security cost and never enable it on an untrusted or guest
 * network. You must also mark each interface `internal` (LAN) or
 * `external` (WAN) with `setUpnpInterface` for it to work.
 *
 * @param {Client} c an open client
 * @example
 *   mt.enableUpnp($c);
 *   mt.setUpnpInterface($c, "ether1", "external");
 *   mt.setUpnpInterface($c, "brlan", "internal");
 */
export func enableUpnp(c as Client) {
    apiRun($c, UPNP_PATH + "/set", {"enabled": "yes"});
}

/**
 * Turn UPnP off.
 *
 * @param {Client} c an open client
 */
export func disableUpnp(c as Client) {
    apiRun($c, UPNP_PATH + "/set", {"enabled": "no"});
}

/**
 * Mark an interface as the internal (LAN) or external (WAN) side for UPnP.
 *
 * Devices on `internal` interfaces may request forwards, opened on the
 * `external` interface. Idempotent - re-setting an interface updates its
 * role.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface
 * @param {string} role          "internal" or "external"
 * @return {string} the RouterOS id of the entry
 * @throws {Error} kind "routeros" on an unknown role or interface
 */
export func setUpnpInterface(c as Client, interfaceName as string, role as string) {
    if (not lists.contains(UPNP_ROLES, $role)) {
        raiseError("unknown UPnP role \"" + $role + "\" - use \"internal\" or \"external\"");
    }
    requiredId($c, INTERFACE_PATH, $interfaceName, "interface");
    def rows as list of map of string to string init getAll($c, UPNP_INTERFACES_PATH);
    def existing as map of string to string init findRowByField($rows, "interface", $interfaceName);
    if (len($existing) > 0) {
        set($c, UPNP_INTERFACES_PATH, rowValue($existing, ".id"), {"type": $role});
        return rowValue($existing, ".id");
    }
    return add($c, UPNP_INTERFACES_PATH, {"interface": $interfaceName, "type": $role});
}

/**
 * Remove an interface's UPnP role.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface
 * @throws {Error} kind "routeros" when the interface has no UPnP role
 */
export func removeUpnpInterface(c as Client, interfaceName as string) {
    def rows as list of map of string to string init getAll($c, UPNP_INTERFACES_PATH);
    def row as map of string to string init findRowByField($rows, "interface", $interfaceName);
    if (len($row) == 0) {
        raiseError("the interface \"" + $interfaceName + "\" has no UPnP role");
    }
    remove($c, UPNP_INTERFACES_PATH, rowValue($row, ".id"));
}

/**
 * Fold a reply row into the UpnpSettings.
 *
 * @param {map of string to string} row the "/ip/upnp/print" row
 * @return {UpnpSettings} the typed settings
 * @internal
 */
func upnpFromRow(row as map of string to string) {
    return UpnpSettings{
        enabled: rowBool($row, "enabled")
    };
}

/**
 * Fold a reply row into an UpnpInterface.
 *
 * @param {map of string to string} row an "/ip/upnp/interfaces/print" row
 * @return {UpnpInterface} the typed interface role
 * @internal
 */
func upnpInterfaceFromRow(row as map of string to string) {
    return UpnpInterface{
        id: rowValue($row, ".id"),
        interfaceName: rowValue($row, "interface"),
        role: rowValue($row, "type"),
        disabled: rowBool($row, "disabled")
    };
}
