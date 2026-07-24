# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - bridges and bridge ports.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the bridge list. */
export def const BRIDGE_PATH as string init "/interface/bridge";

/** RouterOS API path of the bridge-port list. */
export def const BRIDGE_PORT_PATH as string init "/interface/bridge/port";

/** RouterOS API path of the bridge VLAN table (VLAN-aware bridging). */
export def const BRIDGE_VLAN_PATH as string init "/interface/bridge/vlan";

/**
 * One bridge VLAN-table entry: which ports carry a VLAN, tagged or not.
 *
 * @field {string} id       internal RouterOS id
 * @field {string} bridge   the bridge this applies to
 * @field {string} vlanIds  the VLAN id(s), comma/range as reported
 * @field {string} tagged   ports that carry the VLAN with its tag (trunks)
 * @field {string} untagged ports that carry it untagged (access ports)
 * @field {bool}   dynamic  true when learned rather than configured
 */
export def struct BridgeVlan {
    id as string,
    bridge as string,
    vlanIds as string,
    tagged as string,
    untagged as string,
    dynamic as bool
};

/**
 * One bridge (a virtual switch that joins interfaces into one LAN).
 *
 * @field {string} id       internal RouterOS id
 * @field {string} name     bridge name (e.g. "bridge1")
 * @field {string} mac      MAC address the bridge answers with
 * @field {bool}   running  true when the bridge is up
 * @field {bool}   disabled true when the bridge is administratively off
 * @field {string} comment  free-text comment, "" when unset
 */
export def struct Bridge {
    id as string,
    name as string,
    mac as string,
    running as bool,
    disabled as bool,
    comment as string
};

/**
 * One bridge membership: an interface attached to a bridge.
 *
 * @field {string} id              internal RouterOS id
 * @field {string} bridge          name of the bridge
 * @field {string} interfaceName   name of the member interface
 * @field {bool}   hardwareOffload the `hw` flag - true means the port is
 *                                allowed to forward in the switch chip
 *                                (the intent; actual offload also depends
 *                                on the bridge config, see the switch topic)
 * @field {bool}   disabled        true when the membership is off
 */
export def struct BridgePort {
    id as string,
    bridge as string,
    interfaceName as string,
    hardwareOffload as bool,
    disabled as bool
};

/**
 * List every bridge on the router.
 *
 * @param {Client} c an open client
 * @return {list of Bridge} all bridges
 */
export func bridges(c as Client) {
    def rows as list of map of string to string init getAll($c, BRIDGE_PATH);
    def out as list of Bridge init [];
    for (def row in $rows) {
        $out[] = bridgeFromRow($row);
    }
    return $out;
}

/**
 * Create a bridge.
 *
 * A bridge behaves like a network switch inside the router: interfaces
 * added to it with `addBridgePort` share one LAN.
 *
 * @param {Client} c    an open client
 * @param {string} name name for the new bridge (e.g. "brlan")
 * @return {string} the RouterOS id of the new bridge
 * @throws {Error} kind "routeros" on an invalid name, kind "mikrotik" when the router refuses
 */
export func addBridge(c as Client, name as string) {
    ensureName($name, "bridge");
    return add($c, BRIDGE_PATH, {"name": $name});
}

/**
 * Delete a bridge by name.
 *
 * @param {Client} c    an open client
 * @param {string} name name of the bridge to delete
 * @throws {Error} kind "routeros" when no bridge has that name
 */
export func removeBridge(c as Client, name as string) {
    remove($c, BRIDGE_PATH, requiredId($c, BRIDGE_PATH, $name, "bridge"));
}

/**
 * List the interfaces attached to a bridge.
 *
 * @param {Client} c          an open client
 * @param {string} bridgeName name of the bridge
 * @return {list of BridgePort} the bridge's member ports
 */
export func bridgePorts(c as Client, bridgeName as string) {
    def rows as list of map of string to string init getAll($c, BRIDGE_PORT_PATH);
    def out as list of BridgePort init [];
    for (def row in $rows) {
        if (rowValue($row, "bridge") == $bridgeName) {
            $out[] = bridgePortFromRow($row);
        }
    }
    return $out;
}

/**
 * Attach an interface to a bridge.
 *
 * @param {Client} c             an open client
 * @param {string} bridgeName    name of the bridge (must exist)
 * @param {string} interfaceName name of the interface to attach
 * @return {string} the RouterOS id of the new bridge port
 * @throws {Error} kind "routeros" when the bridge does not exist or a name is invalid
 */
export func addBridgePort(c as Client, bridgeName as string, interfaceName as string) {
    ensureName($interfaceName, "interface");
    requiredId($c, BRIDGE_PATH, $bridgeName, "bridge");
    return add($c, BRIDGE_PORT_PATH, {"bridge": $bridgeName, "interface": $interfaceName});
}

/**
 * Detach an interface from whatever bridge it is a member of.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName name of the member interface
 * @throws {Error} kind "routeros" when the interface is on no bridge
 */
export func removeBridgePort(c as Client, interfaceName as string) {
    def rows as list of map of string to string init getAll($c, BRIDGE_PORT_PATH);
    def row as map of string to string init findRowByField($rows, "interface", $interfaceName);
    if (len($row) == 0) {
        raiseError("interface \"" + $interfaceName + "\" is not a port of any bridge");
    }
    remove($c, BRIDGE_PORT_PATH, rowValue($row, ".id"));
}

/**
 * Turn hardware switch-chip offload on or off for a bridge port (`hw`).
 *
 * Offload lets the switch chip forward this port's frames at wire speed
 * without the CPU - the whole point of a VLAN-aware bridge on a
 * switch-capable board. It is on by default where the hardware allows;
 * turn it off to force software forwarding (rarely wanted, e.g. to use
 * a software-only feature on that port). Turning it *on* is only intent
 * - whether the chip actually accelerates also depends on the bridge
 * config; confirm with the switch topic's `switchHosts`.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the bridge port
 * @param {bool}   on            true to allow offload, false to force software
 * @throws {Error} kind "routeros" when the interface is on no bridge
 * @example
 *   def ports as list of mt.BridgePort init mt.bridgePorts($c, "brlan");
 *   for (def p in $ports) { io.printf("%s offload=%t\n", $p.interfaceName, $p.hardwareOffload); }
 */
export func setBridgePortHardwareOffload(c as Client, interfaceName as string, on as bool) {
    def rows as list of map of string to string init getAll($c, BRIDGE_PORT_PATH);
    def row as map of string to string init findRowByField($rows, "interface", $interfaceName);
    if (len($row) == 0) {
        raiseError("interface \"" + $interfaceName + "\" is not a port of any bridge");
    }
    set($c, BRIDGE_PORT_PATH, rowValue($row, ".id"), {"hw": boolWord($on)});
}

/**
 * Fold a reply row into a Bridge.
 *
 * @param {map of string to string} row a "/interface/bridge/print" row
 * @return {Bridge} the typed bridge
 * @internal
 */
func bridgeFromRow(row as map of string to string) {
    return Bridge{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        mac: rowValue($row, "mac-address"),
        running: rowBool($row, "running"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * List the bridge VLAN table.
 *
 * @param {Client} c an open client
 * @return {list of BridgeVlan} all VLAN-table entries
 */
export func bridgeVlans(c as Client) {
    def rows as list of map of string to string init getAll($c, BRIDGE_VLAN_PATH);
    def out as list of BridgeVlan init [];
    for (def row in $rows) {
        $out[] = bridgeVlanFromRow($row);
    }
    return $out;
}

/**
 * Switch a bridge to VLAN-aware mode (hardware VLAN filtering).
 *
 * This is the modern, managed-switch way to do VLANs: instead of
 * separate `/interface/vlan` sub-interfaces, the bridge itself tags,
 * untags, and filters per port. Turn it on, then declare the VLANs with
 * `addBridgeVlan` and set each access port's `pvid` with `setPortPvid`.
 *
 * DANGER: enabling filtering on a bridge before its VLAN table is set
 * up drops untagged traffic - including your own management session if
 * it rides that bridge. Build the VLAN table and PVIDs FIRST, enable
 * filtering LAST, and keep a second way in (see the docs).
 *
 * @param {Client} c      an open client
 * @param {string} bridge the bridge name
 * @throws {Error} kind "routeros" when the bridge does not exist
 * @example
 *   mt.addBridgeVlan($c, "brlan", 10, "ether1", "ether2,ether3");
 *   mt.setPortPvid($c, "brlan", "ether2", 10);
 *   mt.enableVlanFiltering($c, "brlan");   # last, once the table is right
 */
export func enableVlanFiltering(c as Client, bridge as string) {
    set($c, BRIDGE_PATH, requiredId($c, BRIDGE_PATH, $bridge, "bridge"), {"vlan-filtering": "yes"});
}

/**
 * Switch a bridge back to plain (non-VLAN-aware) mode.
 *
 * @param {Client} c      an open client
 * @param {string} bridge the bridge name
 * @throws {Error} kind "routeros" when the bridge does not exist
 */
export func disableVlanFiltering(c as Client, bridge as string) {
    set($c, BRIDGE_PATH, requiredId($c, BRIDGE_PATH, $bridge, "bridge"), {"vlan-filtering": "no"});
}

/**
 * Declare a VLAN on a bridge: which ports carry it, tagged or untagged.
 *
 * Tagged ports are trunks (they keep the VLAN tag - use for links to
 * switches or the router itself); untagged ports are access ports (the
 * tag is stripped - use for end devices, and give each such port a
 * matching `pvid`). Idempotent by bridge + vlan id.
 *
 * @param {Client} c        an open client
 * @param {string} bridge   the VLAN-aware bridge
 * @param {int}    vlanId   the VLAN id (1-4094)
 * @param {string} tagged   trunk ports, comma-separated ("" for none)
 * @param {string} untagged access ports, comma-separated ("" for none)
 * @return {string} the RouterOS id of the (new or existing) entry
 * @throws {Error} kind "routeros" on a bad id or unknown bridge
 */
export func addBridgeVlan(c as Client, bridge as string, vlanId as int, tagged as string, untagged as string) {
    requiredId($c, BRIDGE_PATH, $bridge, "bridge");
    ensureVlanId($vlanId);
    def vid as string init convert.toString($vlanId);
    def rows as list of map of string to string init getAll($c, BRIDGE_VLAN_PATH);
    def existing as map of string to string init findBridgeVlanRow($rows, $bridge, $vid);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    def attrs as map of string to string init {"bridge": $bridge, "vlan-ids": $vid};
    if (strings.trim($tagged) != "") {
        $attrs["tagged"] = normalizedPortList($tagged);
    }
    if (strings.trim($untagged) != "") {
        $attrs["untagged"] = normalizedPortList($untagged);
    }
    return add($c, BRIDGE_VLAN_PATH, $attrs);
}

/**
 * Set an access port's default VLAN (its PVID).
 *
 * Untagged frames entering the port are assigned this VLAN. An access
 * port's pvid must match the VLAN it is `untagged` in.
 *
 * @param {Client} c      an open client
 * @param {string} bridge the VLAN-aware bridge
 * @param {string} port   the bridge port (member interface)
 * @param {int}    pvid   the VLAN id, 1-4094
 * @throws {Error} kind "routeros" on a bad id, or a port not on the bridge
 */
export func setPortPvid(c as Client, bridge as string, port as string, pvid as int) {
    ensureVlanId($pvid);
    def rows as list of map of string to string init getAll($c, BRIDGE_PORT_PATH);
    def row as map of string to string init bridgePortRow($rows, $bridge, $port);
    if (len($row) == 0) {
        raiseError("\"" + $port + "\" is not a port of the bridge \"" + $bridge + "\"");
    }
    set($c, BRIDGE_PORT_PATH, rowValue($row, ".id"), {"pvid": convert.toString($pvid)});
}

/**
 * Remove a VLAN from a bridge's VLAN table.
 *
 * @param {Client} c      an open client
 * @param {string} bridge the bridge
 * @param {int}    vlanId the VLAN id
 * @throws {Error} kind "routeros" when no such entry exists
 */
export func removeBridgeVlan(c as Client, bridge as string, vlanId as int) {
    def rows as list of map of string to string init getAll($c, BRIDGE_VLAN_PATH);
    def row as map of string to string init findBridgeVlanRow($rows, $bridge, convert.toString($vlanId));
    if (len($row) == 0) {
        raiseError("the bridge \"" + $bridge + "\" has no VLAN " + convert.toString($vlanId));
    }
    remove($c, BRIDGE_VLAN_PATH, rowValue($row, ".id"));
}

/**
 * Validate and normalize a comma-separated bridge-port list.
 *
 * @param {string} csv the candidate list
 * @return {string} the normalized list
 * @throws {Error} kind "routeros" on an empty or spaced entry
 * @internal
 */
func normalizedPortList(csv as string) {
    def parts as list of string init strings.split($csv, ",");
    def out as list of string init [];
    for (def part in $parts) {
        def p as string init strings.trim($part);
        ensureName($p, "bridge port");
        $out[] = $p;
    }
    return strings.join($out, ",");
}

/**
 * Find a bridge VLAN entry by bridge and vlan id.
 *
 * @param {list of map of string to string} rows "/interface/bridge/vlan/print" rows
 * @param {string} bridge the bridge
 * @param {string} vid    the vlan id as a string
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func findBridgeVlanRow(rows as list of map of string to string, bridge as string, vid as string) {
    for (def row in $rows) {
        if (rowValue($row, "bridge") == $bridge and rowValue($row, "vlan-ids") == $vid) {
            return $row;
        }
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Find a bridge-port entry by bridge and interface.
 *
 * @param {list of map of string to string} rows "/interface/bridge/port/print" rows
 * @param {string} bridge the bridge
 * @param {string} port   the member interface
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func bridgePortRow(rows as list of map of string to string, bridge as string, port as string) {
    for (def row in $rows) {
        if (rowValue($row, "bridge") == $bridge and rowValue($row, "interface") == $port) {
            return $row;
        }
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Fold a reply row into a BridgeVlan.
 *
 * @param {map of string to string} row an "/interface/bridge/vlan/print" row
 * @return {BridgeVlan} the typed entry
 * @internal
 */
func bridgeVlanFromRow(row as map of string to string) {
    return BridgeVlan{
        id: rowValue($row, ".id"),
        bridge: rowValue($row, "bridge"),
        vlanIds: rowValue($row, "vlan-ids"),
        tagged: rowValue($row, "tagged"),
        untagged: rowValue($row, "untagged"),
        dynamic: rowBool($row, "dynamic")
    };
}

/**
 * Fold a reply row into a BridgePort.
 *
 * @param {map of string to string} row a "/interface/bridge/port/print" row
 * @return {BridgePort} the typed bridge port
 * @internal
 */
func bridgePortFromRow(row as map of string to string) {
    return BridgePort{
        id: rowValue($row, ".id"),
        bridge: rowValue($row, "bridge"),
        interfaceName: rowValue($row, "interface"),
        hardwareOffload: rowBool($row, "hw"),
        disabled: rowBool($row, "disabled")
    };
}
