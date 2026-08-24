# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - system: packages, updates, firmware, reboot.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the installed-package list. */
export def const SYSTEM_PACKAGE_PATH as string init "/system/package";

/** RouterOS API path of the package-update menu. */
export def const SYSTEM_UPDATE_PATH as string init "/system/package/update";

/** RouterOS API path of the routerboard (firmware) menu. */
export def const SYSTEM_ROUTERBOARD_PATH as string init "/system/routerboard";

/** RouterOS API path of the resource (version / memory / load) menu. */
export def const SYSTEM_RESOURCE_PATH as string init "/system/resource";

/** RouterOS API path of the identity (router name) menu. */
export def const SYSTEM_IDENTITY_PATH as string init "/system/identity";

/**
 * One installed RouterOS software package.
 *
 * @field {string} id       internal RouterOS id
 * @field {string} name     package name (e.g. "routeros", "wireless")
 * @field {string} version  installed version (e.g. "7.15.2")
 * @field {bool}   disabled true when the package is disabled
 */
export def struct Package {
    id as string,
    name as string,
    version as string,
    disabled as bool
};

/**
 * The state of the RouterOS package updater.
 *
 * @field {string} channel          release channel ("stable", "testing", ...)
 * @field {string} installedVersion the RouterOS version running now
 * @field {string} latestVersion    the newest version the channel offers, "" when unknown
 * @field {string} status           the updater's own status text
 * @field {bool}   updateAvailable  true when a newer version can be installed
 */
export def struct UpdateStatus {
    channel as string,
    installedVersion as string,
    latestVersion as string,
    status as string,
    updateAvailable as bool
};

/**
 * The routerboard: the hardware and its boot firmware.
 *
 * @field {string} model            hardware model (e.g. "RB4011iGS+")
 * @field {string} serialNumber     hardware serial number
 * @field {string} firmwareType     firmware family (e.g. "al2")
 * @field {string} currentFirmware  firmware version running now
 * @field {string} upgradeFirmware  firmware version available to flash
 * @field {bool}   upgradeAvailable true when `upgradeRouterboard` would change anything
 */
export def struct Routerboard {
    model as string,
    serialNumber as string,
    firmwareType as string,
    currentFirmware as string,
    upgradeFirmware as string,
    upgradeAvailable as bool
};

/**
 * A snapshot of the router's software and load.
 *
 * All values are kept as the router reports them (strings), so nothing
 * breaks when RouterOS changes a unit.
 *
 * @field {string} version      RouterOS version (e.g. "7.15.2 (stable)")
 * @field {string} boardName    board name (e.g. "RB4011iGS+")
 * @field {string} architecture CPU architecture (e.g. "arm64")
 * @field {string} uptime       time since the last boot (e.g. "2w3d4h5m6s")
 * @field {string} cpuLoad      current CPU load in percent
 * @field {string} freeMemory   free RAM in bytes
 * @field {string} totalMemory  total RAM in bytes
 */
export def struct SystemInfo {
    version as string,
    boardName as string,
    architecture as string,
    uptime as string,
    cpuLoad as string,
    freeMemory as string,
    totalMemory as string
};

/**
 * Describe the router: version, hardware, uptime, load, memory.
 *
 * @param {Client} c an open client
 * @return {SystemInfo} the snapshot
 */
export func systemInfo(c as Client) {
    return systemInfoFromRow(singleRow($c, SYSTEM_RESOURCE_PATH));
}

/**
 * Read the router's name (its identity).
 *
 * @param {Client} c an open client
 * @return {string} the router name
 */
export func identity(c as Client) {
    return rowValue(singleRow($c, SYSTEM_IDENTITY_PATH), "name");
}

/**
 * Give the router a new name (its identity).
 *
 * @param {Client} c    an open client
 * @param {string} name the new router name
 * @throws {Error} kind "routeros" on an empty name
 */
export func setIdentity(c as Client, name as string) {
    if (strings.trim($name) == "") {
        raiseError("the router name must not be empty");
    }
    apiRun($c, SYSTEM_IDENTITY_PATH + "/set", {"name": $name});
}

/**
 * List the installed RouterOS software packages.
 *
 * @param {Client} c an open client
 * @return {list of Package} the installed packages
 */
export func packages(c as Client) {
    def rows as list of map of string to string init getAll($c, SYSTEM_PACKAGE_PATH);
    def out as list of Package init [];
    for (def row in $rows) {
        $out[] = packageFromRow($row);
    }
    return $out;
}

/**
 * Ask the update servers whether a newer RouterOS version exists.
 *
 * Read-only: nothing is downloaded or installed. The router needs
 * working internet access (DNS + HTTPS) for this to succeed.
 *
 * @param {Client} c an open client
 * @return {UpdateStatus} the updater state; check `updateAvailable`
 * @throws {Error} kind "mikrotik" when the router cannot reach the update servers
 * @example
 *   def st as mt.UpdateStatus init mt.checkForUpdates($c);
 *   if ($st.updateAvailable) {
 *       io.printf("%s -> %s\n", $st.installedVersion, $st.latestVersion);
 *   }
 */
export func checkForUpdates(c as Client) {
    def none as map of string to string init {};
    def rows as list of map of string to string init
        apiTalk($c, SYSTEM_UPDATE_PATH + "/check-for-updates", $none);
    return updateStatusFromRow(mergeRows($rows));
}

/**
 * Download the newest RouterOS packages without installing them.
 *
 * The downloaded update is installed on the next reboot. Blocks until
 * the download finishes.
 *
 * @param {Client} c an open client
 * @return {UpdateStatus} the updater state after the download
 * @throws {Error} kind "mikrotik" when the download fails
 */
export func downloadUpdates(c as Client) {
    def none as map of string to string init {};
    def rows as list of map of string to string init
        apiTalk($c, SYSTEM_UPDATE_PATH + "/download", $none);
    return updateStatusFromRow(mergeRows($rows));
}

/**
 * Download and install the newest RouterOS packages.
 *
 * The router downloads the update and then REBOOTS ITSELF to apply it.
 * The client is unusable afterwards - reconnect once the router is back
 * up. Run `checkForUpdates` first if you want to know what you will get.
 *
 * @param {Client} c an open client
 * @throws {Error} kind "mikrotik" when the router refuses (e.g. no
 *                 update reachable); a dropped connection caused by the
 *                 reboot itself is expected and swallowed
 */
export func installUpdates(c as Client) {
    runSystemCommand($c, SYSTEM_UPDATE_PATH + "/install");
}

/**
 * Describe the routerboard: hardware model and boot-firmware versions.
 *
 * @param {Client} c an open client
 * @return {Routerboard} the routerboard state; check `upgradeAvailable`
 */
export func routerboard(c as Client) {
    return routerboardFromRow(singleRow($c, SYSTEM_ROUTERBOARD_PATH));
}

/**
 * Stage the routerboard (boot firmware) upgrade.
 *
 * RouterOS ships a matching firmware with every package update, but it
 * is only flashed when you ask for it. This call stages the flash; the
 * new firmware takes effect on the NEXT reboot, so the usual sequence is
 * `upgradeRouterboard` followed by `reboot`. Staging is safe - the
 * connection stays up and nothing changes until the reboot.
 *
 * @param {Client} c an open client
 * @throws {Error} kind "mikrotik" when the router refuses
 */
export func upgradeRouterboard(c as Client) {
    def none as map of string to string init {};
    apiRun($c, SYSTEM_ROUTERBOARD_PATH + "/upgrade", $none);
}

/**
 * Reboot the router now.
 *
 * The connection drops as the router goes down; the client is unusable
 * afterwards - reconnect once the router is back up.
 *
 * @param {Client} c an open client
 * @throws {Error} kind "mikrotik" when the router refuses (e.g. the
 *                 user lacks the reboot policy); a dropped connection
 *                 caused by the reboot itself is expected and swallowed
 */
export func reboot(c as Client) {
    runSystemCommand($c, "/system/reboot");
}

/**
 * Power the router down now.
 *
 * Someone needs physical access to switch it back on - on a remote
 * router you almost always want `reboot` instead.
 *
 * @param {Client} c an open client
 * @throws {Error} kind "mikrotik" when the router refuses; a dropped
 *                 connection caused by the shutdown itself is expected
 *                 and swallowed
 */
export func shutdown(c as Client) {
    runSystemCommand($c, "/system/shutdown");
}

/**
 * Run a command that takes the router down (reboot, shutdown, install).
 *
 * A `!trap` from the router (bad policy, refused command) is re-thrown;
 * a transport error is swallowed, because the connection dropping is
 * exactly what success looks like for these commands.
 *
 * @param {Client} c       an open client
 * @param {string} command the command path (e.g. "/system/reboot")
 * @throws {Error} kind "mikrotik" when the router itself refused
 * @internal
 */
func runSystemCommand(c as Client, command as string) {
    def none as map of string to string init {};
    try {
        apiRun($c, $command, $none);
    } catch (e) {
        if ($e.kind == "mikrotik") {
            throw $e;
        }
    }
}

/**
 * Fold a reply row into a Package.
 *
 * @param {map of string to string} row a "/system/package/print" row
 * @return {Package} the typed package
 * @internal
 */
func packageFromRow(row as map of string to string) {
    return Package{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        version: rowValue($row, "version"),
        disabled: rowBool($row, "disabled")
    };
}

/**
 * Fold a (merged) updater row into an UpdateStatus.
 *
 * `updateAvailable` is computed here: both versions known and different.
 *
 * @param {map of string to string} row the merged updater row
 * @return {UpdateStatus} the typed updater state
 * @internal
 */
func updateStatusFromRow(row as map of string to string) {
    def installed as string init rowValue($row, "installed-version");
    def latest as string init rowValue($row, "latest-version");
    return UpdateStatus{
        channel: rowValue($row, "channel"),
        installedVersion: $installed,
        latestVersion: $latest,
        status: rowValue($row, "status"),
        updateAvailable: $installed != "" and $latest != "" and $installed != $latest
    };
}

/**
 * Fold a reply row into a Routerboard.
 *
 * `upgradeAvailable` is computed here: both firmware versions known and
 * different.
 *
 * @param {map of string to string} row a "/system/routerboard/print" row
 * @return {Routerboard} the typed routerboard state
 * @internal
 */
func routerboardFromRow(row as map of string to string) {
    def current as string init rowValue($row, "current-firmware");
    def upgrade as string init rowValue($row, "upgrade-firmware");
    return Routerboard{
        model: rowValue($row, "model"),
        serialNumber: rowValue($row, "serial-number"),
        firmwareType: rowValue($row, "firmware-type"),
        currentFirmware: $current,
        upgradeFirmware: $upgrade,
        upgradeAvailable: $current != "" and $upgrade != "" and $current != $upgrade
    };
}

/**
 * Fold a reply row into a SystemInfo.
 *
 * @param {map of string to string} row a "/system/resource/print" row
 * @return {SystemInfo} the typed snapshot
 * @internal
 */
func systemInfoFromRow(row as map of string to string) {
    return SystemInfo{
        version: rowValue($row, "version"),
        boardName: rowValue($row, "board-name"),
        architecture: rowValue($row, "architecture-name"),
        uptime: rowValue($row, "uptime"),
        cpuLoad: rowValue($row, "cpu-load"),
        freeMemory: rowValue($row, "free-memory"),
        totalMemory: rowValue($row, "total-memory")
    };
}

/** RouterOS API path of the device-mode settings. */
export def const DEVICE_MODE_PATH as string init "/system/device-mode";

/** RouterOS API command that requests a device-mode change. */
export def const DEVICE_MODE_UPDATE_COMMAND as string init "/system/device-mode/update";

/** Device mode: the locked-down factory default on most models. */
export def const DEVICE_MODE_HOME as string init "home";

/** Device mode: unlocks container, scheduler, fetch, e-mail and friends. */
export def const DEVICE_MODE_ADVANCED as string init "advanced";

/** Device mode: everything unlocked, for managed deployments. */
export def const DEVICE_MODE_ENTERPRISE as string init "enterprise";

/**
 * The router's device mode and the features it gates.
 *
 * @field {string} mode              the active mode ("home" / "advanced" / "enterprise")
 * @field {bool}   flaggingEnabled   true when tamper flagging is on
 * @field {bool}   container         true when containers may run
 * @field {bool}   scheduler         true when the scheduler may run scripts
 * @field {bool}   fetch             true when /tool/fetch is allowed
 * @field {bool}   email             true when the router may send e-mail
 * @field {bool}   socks             true when the SOCKS proxy is allowed
 * @field {bool}   installAnyVersion true when downgrades are permitted
 */
export def struct DeviceMode {
    mode as string,
    flaggingEnabled as bool,
    container as bool,
    scheduler as bool,
    fetch as bool,
    email as bool,
    socks as bool,
    installAnyVersion as bool
};

/**
 * Read the router's device mode.
 *
 * Worth checking first when a feature "does not exist": on a router in
 * `home` mode the scheduler, fetch, e-mail and containers are gated off
 * and the API reports them missing rather than refused.
 *
 * @param {Client} c an open client
 * @return {DeviceMode} the active mode and its feature flags
 * @example
 *   def d as mt.DeviceMode init mt.deviceMode($c);
 *   if (not $d.scheduler) { io.printf("scheduler is gated off in %s mode\n", $d.mode); }
 */
export func deviceMode(c as Client) {
    return deviceModeFromRow(singleRow($c, DEVICE_MODE_PATH));
}

/**
 * Request a device-mode change.
 *
 * THIS CALL DOES NOT FINISH THE JOB. RouterOS deliberately requires
 * physical proof that whoever asked for the change is standing at the
 * router: after this returns, the change is only *pending*, and the
 * router applies it when someone power-cycles it (a cold boot - not
 * `reboot`) or presses the reset button, within a few minutes. Miss
 * that window and the request is discarded silently, leaving the mode
 * as it was. So do not call this from an unattended script and expect
 * the mode to change, and do not follow it with `reboot` - a soft
 * reboot is not the confirmation the router is waiting for.
 *
 * Raising the mode (`home` -> `advanced` -> `enterprise`) is what needs
 * confirmation because it unlocks code execution; check the result with
 * `deviceMode` once the router is back.
 *
 * @param {Client} c    an open client
 * @param {string} mode one of the DEVICE_MODE_* constants
 * @throws {Error} kind "routeros" on an unknown mode, kind "mikrotik"
 *                 when the router refuses the request
 * @example
 *   mt.updateDeviceMode($c, mt.DEVICE_MODE_ADVANCED);
 *   # now power-cycle the router, then:
 *   #   io.printf("%s\n", mt.deviceMode($c).mode);
 */
export func updateDeviceMode(c as Client, mode as string) {
    def target as string init strings.trim($mode);
    ensureDeviceMode($target);
    apiRun($c, DEVICE_MODE_UPDATE_COMMAND, {"mode": $target});
}

/**
 * Fold a reply row into a DeviceMode.
 *
 * @param {map of string to string} row a "/system/device-mode/print" row
 * @return {DeviceMode} the typed mode
 * @internal
 */
func deviceModeFromRow(row as map of string to string) {
    return DeviceMode{
        mode: rowValue($row, "mode"),
        flaggingEnabled: rowBool($row, "flagging-enabled"),
        container: rowBool($row, "container"),
        scheduler: rowBool($row, "scheduler"),
        fetch: rowBool($row, "fetch"),
        email: rowBool($row, "email"),
        socks: rowBool($row, "socks"),
        installAnyVersion: rowBool($row, "install-any-version")
    };
}

/**
 * Validate a device mode against the DEVICE_MODE_* constants.
 *
 * @param {string} mode the candidate mode
 * @throws {Error} kind "routeros" on an unknown mode
 * @internal
 */
func ensureDeviceMode(mode as string) {
    if ($mode != DEVICE_MODE_HOME and $mode != DEVICE_MODE_ADVANCED and $mode != DEVICE_MODE_ENTERPRISE) {
        raiseError("\"" + $mode + "\" is not a device mode - use DEVICE_MODE_HOME, DEVICE_MODE_ADVANCED, or DEVICE_MODE_ENTERPRISE");
    }
}
