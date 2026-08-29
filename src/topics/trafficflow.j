# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - traffic flow: export NetFlow / IPFIX to a collector.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the traffic-flow settings. */
export def const TRAFFIC_FLOW_PATH as string init "/ip/traffic-flow";

/** RouterOS API path of the traffic-flow export targets (collectors). */
export def const TRAFFIC_FLOW_TARGET_PATH as string init "/ip/traffic-flow/target";

def const FLOW_VERSIONS as list of string init ["1", "5", "9", "ipfix"];

/**
 * The traffic-flow (NetFlow/IPFIX) settings.
 *
 * @field {bool}   enabled    true when flow accounting is running
 * @field {string} interfaces the interfaces accounted, "all" for every one
 */
export def struct TrafficFlowSettings {
    enabled as bool,
    interfaces as string
};

/**
 * One traffic-flow export target (a collector).
 *
 * @field {string} id       internal RouterOS id
 * @field {string} address  the collector's address
 * @field {string} port     the collector's UDP port
 * @field {string} version  the export protocol version ("5", "9", "ipfix")
 * @field {bool}   disabled true when switched off
 */
export def struct FlowTarget {
    id as string,
    address as string,
    port as string,
    version as string,
    disabled as bool
};

/**
 * Read the traffic-flow settings.
 *
 * @param {Client} c an open client
 * @return {TrafficFlowSettings} the state
 */
export func trafficFlowStatus(c as Client) {
    return trafficFlowFromRow(singleRow($c, TRAFFIC_FLOW_PATH));
}

/**
 * List the traffic-flow export targets.
 *
 * @param {Client} c an open client
 * @return {list of FlowTarget} all collectors
 */
export func flowTargets(c as Client) {
    def rows as list of map of string to string init getAll($c, TRAFFIC_FLOW_TARGET_PATH);
    def out as list of FlowTarget init [];
    for (def row in $rows) {
        $out[] = flowTargetFromRow($row);
    }
    return $out;
}

/**
 * Turn flow accounting on (for all interfaces).
 *
 * Traffic flow samples every connection and exports per-flow records to
 * a NetFlow/IPFIX collector (ntopng, Elastiflow, a commercial appliance)
 * for bandwidth and top-talker analysis. Enable it, then point it at a
 * collector with `addFlowTarget` - both are needed.
 *
 * @param {Client} c an open client
 * @example
 *   mt.enableTrafficFlow($c);
 *   mt.addFlowTarget($c, "10.0.9.30", 2055, "ipfix");
 */
export func enableTrafficFlow(c as Client) {
    apiRun($c, TRAFFIC_FLOW_PATH + "/set", {"enabled": "yes", "interfaces": "all"});
}

/**
 * Turn flow accounting off.
 *
 * @param {Client} c an open client
 */
export func disableTrafficFlow(c as Client) {
    apiRun($c, TRAFFIC_FLOW_PATH + "/set", {"enabled": "no"});
}

/**
 * Export flow records to a collector.
 *
 * `ipfix` (or NetFlow v9) is the modern choice; v5 is the widest-
 * compatible legacy option. Idempotent by address + port.
 *
 * @param {Client} c       an open client
 * @param {string} address the collector's address
 * @param {int}    port    its UDP port (e.g. 2055 for NetFlow, 4739 for IPFIX)
 * @param {string} version "5", "9", or "ipfix"
 * @return {string} the RouterOS id of the (new or existing) target
 * @throws {Error} kind "routeros" on a bad address, port, or version
 */
export func addFlowTarget(c as Client, address as string, port as int, version as string) {
    def collector as string init strings.trim($address);
    ensureIpAddress($collector);
    ensurePort($port);
    if (not lists.contains(FLOW_VERSIONS, $version)) {
        raiseError("unknown NetFlow version \"" + $version + "\" - use one of: " +
            strings.join(FLOW_VERSIONS, ", "));
    }
    def portStr as string init convert.toString($port);
    def rows as list of map of string to string init getAll($c, TRAFFIC_FLOW_TARGET_PATH);
    for (def row in $rows) {
        if (rowValue($row, "address") == $collector and rowValue($row, "port") == $portStr) {
            return rowValue($row, ".id");
        }
    }
    return add(
        $c,
        TRAFFIC_FLOW_TARGET_PATH,
        {"address": $collector, "port": $portStr, "version": $version});
}

/**
 * Remove a traffic-flow target by its address.
 *
 * @param {Client} c       an open client
 * @param {string} address the collector's address
 * @throws {Error} kind "routeros" when no target has that address
 */
export func removeFlowTarget(c as Client, address as string) {
    def rows as list of map of string to string init getAll($c, TRAFFIC_FLOW_TARGET_PATH);
    def row as map of string to string init findRowByField(
        $rows,
        "address",
        strings.trim($address));
    if (len($row) == 0) {
        raiseError("no traffic-flow target at \"" + $address + "\" was found");
    }
    remove($c, TRAFFIC_FLOW_TARGET_PATH, rowValue($row, ".id"));
}

/**
 * Fold a reply row into the TrafficFlowSettings.
 *
 * @param {map of string to string} row the "/ip/traffic-flow/print" row
 * @return {TrafficFlowSettings} the typed settings
 * @internal
 */
func trafficFlowFromRow(row as map of string to string) {
    return TrafficFlowSettings{
        enabled: rowBool($row, "enabled"),
        interfaces: rowValue($row, "interfaces")
    };
}

/**
 * Fold a reply row into a FlowTarget.
 *
 * @param {map of string to string} row an "/ip/traffic-flow/target/print" row
 * @return {FlowTarget} the typed target
 * @internal
 */
func flowTargetFromRow(row as map of string to string) {
    return FlowTarget{
        id: rowValue($row, ".id"),
        address: rowValue($row, "address"),
        port: rowValue($row, "port"),
        version: rowValue($row, "version"),
        disabled: rowBool($row, "disabled")
    };
}
