# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - switch chip: hardware-offload inventory and host table.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the ethernet switch chip(s). */
export def const ETHERNET_SWITCH_PATH as string init "/interface/ethernet/switch";

/** RouterOS API path of the switch chip's hardware MAC host table. */
export def const ETHERNET_SWITCH_HOST_PATH as string init "/interface/ethernet/switch/host";

/**
 * One switch chip on the router.
 *
 * @field {string} id   internal RouterOS id
 * @field {string} name the chip name (e.g. "switch1")
 * @field {string} kind the chip model as reported (e.g. "Atheros-8327")
 */
export def struct SwitchChip {
    id as string,
    name as string,
    kind as string
};

/**
 * One entry in the switch chip's hardware MAC table.
 *
 * A populated table is the honest sign that traffic is being forwarded
 * in hardware (the chip learned the MAC) rather than by the CPU.
 *
 * @field {string} mac     the learned MAC address
 * @field {string} ports   the switch port(s) it was learned on
 * @field {int}    vlanId  the VLAN it belongs to (0 when untagged / not reported)
 * @field {bool}   dynamic true when learned, false for a static entry
 */
export def struct SwitchHost {
    mac as string,
    ports as string,
    vlanId as int,
    dynamic as bool
};

/**
 * List the switch chip(s) on the router.
 *
 * Returns an empty list on routers without a switch chip (a pure-CPU
 * board). Having a chip is what makes wire-speed switching and the
 * bridge hardware-offload possible.
 *
 * @param {Client} c an open client
 * @return {list of SwitchChip} the switch chips
 */
export func switchChips(c as Client) {
    def out as list of SwitchChip init [];
    def rows as list of map of string to string init [];
    try {
        $rows = getAll($c, ETHERNET_SWITCH_PATH);
    } catch (e) {
        return $out;
    }
    for (def row in $rows) {
        $out[] = switchChipFromRow($row);
    }
    return $out;
}

/**
 * Read the switch chip's hardware MAC table.
 *
 * If this is populated for your LAN's MACs, the switch chip is doing the
 * forwarding - the traffic never reaches the CPU. If your VLAN-aware
 * bridge is offloading (bridge ports with `hardwareOffload == true`),
 * the learned hosts show up here. An empty table on a busy LAN, with the
 * CPU high, means offload is NOT engaging - something in the config
 * forced software forwarding.
 *
 * The table can be large; this returns all of it.
 *
 * @param {Client} c an open client
 * @return {list of SwitchHost} the hardware MAC entries
 */
export func switchHosts(c as Client) {
    def out as list of SwitchHost init [];
    def rows as list of map of string to string init [];
    try {
        $rows = getAll($c, ETHERNET_SWITCH_HOST_PATH);
    } catch (e) {
        return $out;
    }
    for (def row in $rows) {
        $out[] = switchHostFromRow($row);
    }
    return $out;
}

/**
 * Fold a reply row into a SwitchChip.
 *
 * @param {map of string to string} row an "/interface/ethernet/switch/print" row
 * @return {SwitchChip} the typed chip
 * @internal
 */
func switchChipFromRow(row as map of string to string) {
    return SwitchChip{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        kind: rowValue($row, "type")
    };
}

/**
 * Fold a reply row into a SwitchHost.
 *
 * @param {map of string to string} row a switch host-table row
 * @return {SwitchHost} the typed entry
 * @internal
 */
func switchHostFromRow(row as map of string to string) {
    return SwitchHost{
        mac: rowValue($row, "mac-address"),
        ports: rowValue($row, "ports"),
        vlanId: rowInt($row, "vlan-id"),
        dynamic: rowBool($row, "dynamic")
    };
}
