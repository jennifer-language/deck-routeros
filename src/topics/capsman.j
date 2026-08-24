# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - CAPsMAN: central management of many access points.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the legacy CAPsMAN manager (classic wireless, v1). */
export def const CAPSMAN_PATH as string init "/caps-man/manager";

/** RouterOS API path of the legacy CAPsMAN registration table (clients on managed APs). */
export def const CAPSMAN_REGISTRATION_PATH as string init "/caps-man/registration-table";

/** RouterOS API path of the legacy CAPsMAN remote APs. */
export def const CAPSMAN_REMOTE_PATH as string init "/caps-man/remote-cap";

/** RouterOS API path of the CAPsMANv2 manager (wifiwave2, RouterOS v7). */
export def const WIFI_CAPSMAN_PATH as string init "/interface/wifi/capsman";

/** RouterOS API path of the CAPsMANv2 managed remote APs. */
export def const WIFI_CAP_PATH as string init "/interface/wifi/cap";

/**
 * The state of a CAPsMAN controller (either generation).
 *
 * @field {bool}   enabled     true when the controller is running
 * @field {int}    version     1 (legacy /caps-man) or 2 (wifiwave2 /interface/wifi)
 * @field {int}    managedAps  how many access points it currently manages
 */
export def struct CapsmanStatus {
    enabled as bool,
    version as int,
    managedAps as int
};

/**
 * One access point registered with the controller.
 *
 * @field {string} identity   the AP's identity/name
 * @field {string} address    where the AP connected from
 * @field {string} interfaceName the managed radio interface
 * @field {string} state      the AP's provisioning state
 */
export def struct ManagedAp {
    identity as string,
    address as string,
    interfaceName as string,
    state as string
};

/**
 * Read the CAPsMAN controller state, trying both generations.
 *
 * CAPsMAN turns one router into the brain for many access points -
 * push one SSID/password/config and every AP inherits it, and clients
 * roam between them. RouterOS has two incompatible generations: legacy
 * `/caps-man` (classic wireless hardware) and CAPsMANv2 under
 * `/interface/wifi` (wifiwave2/ax hardware). This reports whichever the
 * router has; `version` says which.
 *
 * @param {Client} c an open client
 * @return {CapsmanStatus} the controller state (version 0 when neither exists)
 */
export func capsmanStatus(c as Client) {
    def v2 as map of string to string init tryFirstRow($c, WIFI_CAPSMAN_PATH);
    if (len($v2) > 0) {
        return CapsmanStatus{
            enabled: rowBool($v2, "enabled"),
            version: 2,
            managedAps: countRows($c, WIFI_CAP_PATH)
        };
    }
    def v1 as map of string to string init tryFirstRow($c, CAPSMAN_PATH);
    if (len($v1) > 0) {
        return CapsmanStatus{
            enabled: rowBool($v1, "enabled"),
            version: 1,
            managedAps: countRows($c, CAPSMAN_REMOTE_PATH)
        };
    }
    return CapsmanStatus{enabled: false, version: 0, managedAps: 0};
}

/**
 * Turn the CAPsMAN controller on (whichever generation the router has).
 *
 * Enabling the manager is only step one - the SSID/security
 * "configuration" and the "provisioning" rules that bind it to joining
 * APs are the substance, and those stay with the generic verbs
 * (`/caps-man/configuration` + `/caps-man/provisioning`, or
 * `/interface/wifi/configuration` + `/interface/wifi/provisioning`)
 * because their shape differs sharply between the two generations.
 *
 * @param {Client} c an open client
 * @throws {Error} kind "routeros" when the router has no CAPsMAN menu
 */
export func enableCapsman(c as Client) {
    if (len(tryFirstRow($c, WIFI_CAPSMAN_PATH)) > 0) {
        apiRun($c, WIFI_CAPSMAN_PATH + "/set", {"enabled": "yes"});
        return;
    }
    if (len(tryFirstRow($c, CAPSMAN_PATH)) > 0) {
        apiRun($c, CAPSMAN_PATH + "/set", {"enabled": "yes"});
        return;
    }
    raiseError("this router has no CAPsMAN menu (needs the wireless or wifiwave2 package)");
}

/**
 * Turn the CAPsMAN controller off.
 *
 * @param {Client} c an open client
 * @throws {Error} kind "routeros" when the router has no CAPsMAN menu
 */
export func disableCapsman(c as Client) {
    if (len(tryFirstRow($c, WIFI_CAPSMAN_PATH)) > 0) {
        apiRun($c, WIFI_CAPSMAN_PATH + "/set", {"enabled": "no"});
        return;
    }
    if (len(tryFirstRow($c, CAPSMAN_PATH)) > 0) {
        apiRun($c, CAPSMAN_PATH + "/set", {"enabled": "no"});
        return;
    }
    raiseError("this router has no CAPsMAN menu (needs the wireless or wifiwave2 package)");
}

/**
 * List the access points the controller manages.
 *
 * @param {Client} c an open client
 * @return {list of ManagedAp} the registered APs (empty when none / no CAPsMAN)
 */
export func managedAps(c as Client) {
    def out as list of ManagedAp init [];
    def rows as list of map of string to string init tryGetAll($c, WIFI_CAP_PATH);
    if (len($rows) == 0) {
        $rows = tryGetAll($c, CAPSMAN_REMOTE_PATH);
    }
    for (def row in $rows) {
        $out[] = managedApFromRow($row);
    }
    return $out;
}

/**
 * Read a single-row menu, returning an empty map when the path is absent.
 *
 * @param {Client} c    an open client
 * @param {string} path the menu path
 * @return {map of string to string} the first row, or an empty map
 * @internal
 */
func tryFirstRow(c as Client, path as string) {
    def rows as list of map of string to string init tryGetAll($c, $path);
    if (len($rows) > 0) {
        return $rows[0];
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * getAll that returns an empty list instead of throwing on an absent path.
 *
 * @param {Client} c    an open client
 * @param {string} path the list path
 * @return {list of map of string to string} the rows, or an empty list
 * @internal
 */
func tryGetAll(c as Client, path as string) {
    def rows as list of map of string to string init [];
    try {
        $rows = getAll($c, $path);
    } catch (e) {
    }
    return $rows;
}

/**
 * Count the rows under a path (0 when absent).
 *
 * @param {Client} c    an open client
 * @param {string} path the list path
 * @return {int} the row count
 * @internal
 */
func countRows(c as Client, path as string) {
    return len(tryGetAll($c, $path));
}

/**
 * Fold a reply row into a ManagedAp (both CAPsMAN generations).
 *
 * @param {map of string to string} row a remote-cap / cap row
 * @return {ManagedAp} the typed AP
 * @internal
 */
func managedApFromRow(row as map of string to string) {
    return ManagedAp{
        identity: rowValue($row, "identity"),
        address: rowValue($row, "address"),
        interfaceName: rowValue($row, "interface"),
        state: rowValue($row, "state")
    };
}
