# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - neighbor discovery: what is on this segment (LLDP/CDP/MNDP).
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the discovered-neighbor list. */
export def const NEIGHBOR_PATH as string init "/ip/neighbor";

/**
 * One discovered neighbor on a directly-connected segment.
 *
 * @field {string} interfaceName the interface it was seen on
 * @field {string} address       its IP address, "" when only layer 2
 * @field {string} mac           its MAC address
 * @field {string} identity      its host name / identity
 * @field {string} platform      the vendor platform (e.g. "MikroTik", "Cisco")
 * @field {string} board         the hardware model as reported
 * @field {string} version       the software version as reported
 */
export def struct Neighbor {
    interfaceName as string,
    address as string,
    mac as string,
    identity as string,
    platform as string,
    board as string,
    version as string
};

/**
 * List the neighbors the router has discovered.
 *
 * "What is plugged into this segment" - the router hears LLDP (most
 * vendors), CDP (Cisco), and MNDP (MikroTik) announcements from directly
 * connected devices. A fast way to map a rack or find that one switch.
 * Only same-segment neighbors appear; nothing behind another router.
 *
 * @param {Client} c an open client
 * @return {list of Neighbor} the discovered neighbors
 */
export func neighbors(c as Client) {
    def rows as list of map of string to string init getAll($c, NEIGHBOR_PATH);
    def out as list of Neighbor init [];
    for (def row in $rows) {
        $out[] = neighborFromRow($row);
    }
    return $out;
}

/**
 * The neighbors discovered on one interface.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface to filter for
 * @return {list of Neighbor} that interface's neighbors
 */
export func neighborsOn(c as Client, interfaceName as string) {
    def all as list of Neighbor init neighbors($c);
    def out as list of Neighbor init [];
    for (def n in $all) {
        if ($n.interfaceName == $interfaceName) {
            $out[] = $n;
        }
    }
    return $out;
}

/**
 * Fold a reply row into a Neighbor.
 *
 * @param {map of string to string} row an "/ip/neighbor/print" row
 * @return {Neighbor} the typed neighbor
 * @internal
 */
func neighborFromRow(row as map of string to string) {
    return Neighbor{
        interfaceName: rowValue($row, "interface"),
        address: rowValue($row, "address"),
        mac: rowValue($row, "mac-address"),
        identity: rowValue($row, "identity"),
        platform: rowValue($row, "platform"),
        board: rowValue($row, "board"),
        version: rowValue($row, "version")
    };
}
