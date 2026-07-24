# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - WiFi: radios, security profiles, clients.
# Spliced into routeros.j via include - not a standalone module.

/**
 * RouterOS API path of the wireless interface list.
 *
 * This is the classic wireless menu (the "wireless" package). Recent
 * wifiwave2 / ax hardware uses "/interface/wifi" instead - drive that
 * with the generic verbs if your router has no "/interface/wireless".
 */
export def const WIRELESS_PATH as string init "/interface/wireless";

/** RouterOS API path of the wireless security profiles (WPA keys). */
export def const WIRELESS_SECURITY_PATH as string init "/interface/wireless/security-profiles";

/** RouterOS API path of the wireless registration table (connected clients). */
export def const WIRELESS_REGISTRATION_PATH as string init "/interface/wireless/registration-table";

/**
 * One wireless interface: a radio, or a virtual AP on top of one.
 *
 * @field {string} id              internal RouterOS id
 * @field {string} name            interface name (e.g. "wlan1")
 * @field {string} ssid            network name the radio broadcasts
 * @field {string} mode            "ap-bridge" (access point), "station" (client), ...
 * @field {string} band            radio band (e.g. "2ghz-b/g/n", "5ghz-a/n/ac")
 * @field {string} frequency       channel frequency in MHz, or "auto"
 * @field {string} securityProfile name of the security profile holding the password
 * @field {string} masterInterface "" for a physical radio; the radio's name
 *                                 for a virtual AP
 * @field {bool}   running         true when the radio is up and serving
 * @field {bool}   disabled        true when the interface is switched off
 * @field {string} comment         free-text comment, "" when unset
 */
export def struct WirelessInterface {
    id as string,
    name as string,
    ssid as string,
    mode as string,
    band as string,
    frequency as string,
    securityProfile as string,
    masterInterface as string,
    running as bool,
    disabled as bool,
    comment as string
};

/**
 * One connected wireless client (a registration-table entry).
 *
 * @field {string} interfaceName wireless interface the client is on
 * @field {string} mac           the client's MAC address
 * @field {string} signalStrength signal as reported (e.g. "-52dBm")
 * @field {string} txRate        current transmit rate as reported
 * @field {string} rxRate        current receive rate as reported
 * @field {string} uptime        how long the client has been connected
 */
export def struct WifiClient {
    interfaceName as string,
    mac as string,
    signalStrength as string,
    txRate as string,
    rxRate as string,
    uptime as string
};

/**
 * List every wireless interface: physical radios and virtual APs.
 *
 * Returns an empty list on routers without the classic wireless menu
 * (wired-only models, or wifiwave2 hardware using "/interface/wifi").
 *
 * @param {Client} c an open client
 * @return {list of WirelessInterface} all wireless interfaces
 */
export func wirelessInterfaces(c as Client) {
    def out as list of WirelessInterface init [];
    def rows as list of map of string to string init [];
    try {
        $rows = getAll($c, WIRELESS_PATH);
    } catch (e) {
        return $out;
    }
    for (def row in $rows) {
        $out[] = wirelessFromRow($row);
    }
    return $out;
}

/**
 * Turn a radio into a working, WPA2-protected access point in one call.
 *
 * Sets the SSID, puts the interface into access-point mode, stores the
 * password in a dedicated security profile (never in the shared
 * "default" profile, so other radios are unaffected), wires the profile
 * to the interface, and enables it. Safe to call again to change the
 * SSID or password.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the radio (e.g. "wlan1")
 * @param {string} ssid          network name to broadcast, 1-32 characters
 *                               (spaces are fine)
 * @param {string} password      WPA2 passphrase, 8-63 characters
 * @throws {Error} kind "routeros" on a bad SSID / password or an
 *                 unknown wireless interface
 * @example
 *   mt.setupWifiAccessPoint($c, "wlan1", "My Home WiFi", "correct horse battery");
 */
export func setupWifiAccessPoint(c as Client, interfaceName as string, ssid as string, password as string) {
    ensureSsid($ssid);
    ensureWifiPassword($password);
    def id as string init requiredId($c, WIRELESS_PATH, $interfaceName, "wireless interface");
    def profile as string init ensureWifiProfile($c, wifiProfileName($interfaceName), $password);
    set($c, WIRELESS_PATH, $id, {
        "ssid": $ssid,
        "security-profile": $profile,
        "mode": "ap-bridge",
        "disabled": "no"
    });
}

/**
 * Change the network name (SSID) a radio broadcasts.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the wireless interface
 * @param {string} ssid          the new name, 1-32 characters
 * @throws {Error} kind "routeros" on a bad SSID or unknown interface
 */
export func setWifiSsid(c as Client, interfaceName as string, ssid as string) {
    ensureSsid($ssid);
    set($c, WIRELESS_PATH, requiredId($c, WIRELESS_PATH, $interfaceName, "wireless interface"), {"ssid": $ssid});
}

/**
 * Change the WiFi password of a radio.
 *
 * The password lives in the interface's security profile. If the
 * interface still sits on the shared "default" profile, it is moved to
 * a dedicated one first, so the change never affects other radios.
 * Connected clients are dropped and must reconnect with the new password.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the wireless interface
 * @param {string} password      the new WPA2 passphrase, 8-63 characters
 * @throws {Error} kind "routeros" on a bad password or unknown interface
 */
export func setWifiPassword(c as Client, interfaceName as string, password as string) {
    ensureWifiPassword($password);
    def row as map of string to string init findByName($c, WIRELESS_PATH, $interfaceName);
    if (len($row) == 0) {
        raiseError("the wireless interface \"" + $interfaceName + "\" was not found on the router");
    }
    def profile as string init rowValue($row, "security-profile");
    if ($profile == "" or $profile == "default") {
        def dedicated as string init ensureWifiProfile($c, wifiProfileName($interfaceName), $password);
        set($c, WIRELESS_PATH, rowValue($row, ".id"), {"security-profile": $dedicated});
    } else {
        ensureWifiProfile($c, $profile, $password);
    }
}

/**
 * Add a second wireless network on an existing radio (a virtual AP) -
 * the usual way to run a guest WiFi next to the main one.
 *
 * The virtual AP gets its own SSID and its own password (own security
 * profile) but shares the radio and channel of its master.
 *
 * @param {Client} c               an open client
 * @param {string} masterInterface the physical radio to piggyback on (e.g. "wlan1")
 * @param {string} name            name for the new interface (e.g. "wlanguest")
 * @param {string} ssid            network name to broadcast, 1-32 characters
 * @param {string} password        WPA2 passphrase, 8-63 characters
 * @return {string} the RouterOS id of the new virtual AP
 * @throws {Error} kind "routeros" on bad input or an unknown master radio
 */
export func addVirtualAp(c as Client, masterInterface as string, name as string, ssid as string, password as string) {
    ensureName($name, "interface");
    ensureSsid($ssid);
    ensureWifiPassword($password);
    requiredId($c, WIRELESS_PATH, $masterInterface, "wireless interface");
    def profile as string init ensureWifiProfile($c, wifiProfileName($name), $password);
    return add($c, WIRELESS_PATH, {
        "name": $name,
        "master-interface": $masterInterface,
        "ssid": $ssid,
        "security-profile": $profile,
        "mode": "ap-bridge",
        "disabled": "no"
    });
}

/**
 * Remove a virtual AP.
 *
 * Physical radios cannot be removed, only disabled - this refuses them
 * with a clear message instead of letting the router trap. The
 * dedicated security profile is kept (harmless, and reused if the AP
 * comes back).
 *
 * @param {Client} c    an open client
 * @param {string} name the virtual AP's interface name
 * @throws {Error} kind "routeros" when the interface is unknown or is
 *                 a physical radio
 */
export func removeVirtualAp(c as Client, name as string) {
    def row as map of string to string init findByName($c, WIRELESS_PATH, $name);
    if (len($row) == 0) {
        raiseError("the wireless interface \"" + $name + "\" was not found on the router");
    }
    if (rowValue($row, "master-interface") == "") {
        raiseError("\"" + $name + "\" is a physical radio - it can be disabled, not removed");
    }
    remove($c, WIRELESS_PATH, rowValue($row, ".id"));
}

/**
 * Switch a wireless interface on.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the wireless interface
 * @throws {Error} kind "routeros" when no such wireless interface exists
 */
export func enableWifi(c as Client, interfaceName as string) {
    enable($c, WIRELESS_PATH, requiredId($c, WIRELESS_PATH, $interfaceName, "wireless interface"));
}

/**
 * Switch a wireless interface off; its network disappears from the air.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the wireless interface
 * @throws {Error} kind "routeros" when no such wireless interface exists
 */
export func disableWifi(c as Client, interfaceName as string) {
    disable($c, WIRELESS_PATH, requiredId($c, WIRELESS_PATH, $interfaceName, "wireless interface"));
}

/**
 * List the wireless clients connected right now.
 *
 * Returns an empty list on routers without the classic wireless menu.
 *
 * @param {Client} c an open client
 * @return {list of WifiClient} one entry per connected device
 */
export func wifiClients(c as Client) {
    def out as list of WifiClient init [];
    def rows as list of map of string to string init [];
    try {
        $rows = getAll($c, WIRELESS_REGISTRATION_PATH);
    } catch (e) {
        return $out;
    }
    for (def row in $rows) {
        $out[] = wifiClientFromRow($row);
    }
    return $out;
}

/**
 * Validate an SSID: non-empty, at most 32 characters, spaces allowed.
 *
 * @param {string} ssid the candidate network name
 * @throws {Error} kind "routeros" when empty or too long
 * @internal
 */
func ensureSsid(ssid as string) {
    if (strings.trim($ssid) == "") {
        raiseError("the SSID (network name) must not be empty");
    }
    if (len($ssid) > 32) {
        raiseError("the SSID must be at most 32 characters");
    }
}

/**
 * Validate a WPA2 passphrase: 8 to 63 characters.
 *
 * @param {string} password the candidate passphrase
 * @throws {Error} kind "routeros" when outside 8-63 characters
 * @internal
 */
func ensureWifiPassword(password as string) {
    if (len($password) < 8) {
        raiseError("the WiFi password must be at least 8 characters (WPA2 requirement)");
    }
    if (len($password) > 63) {
        raiseError("the WiFi password must be at most 63 characters (WPA2 requirement)");
    }
}

/**
 * The name of the dedicated security profile routeros manages for a
 * wireless interface.
 *
 * @param {string} interfaceName the wireless interface
 * @return {string} the deterministic profile name
 * @internal
 */
func wifiProfileName(interfaceName as string) {
    return "routeros-" + $interfaceName;
}

/**
 * Create or update a WPA2-PSK security profile with a password.
 *
 * Idempotent: an existing profile of that name is updated in place.
 *
 * @param {Client} c           an open client
 * @param {string} profileName the profile to create or update
 * @param {string} password    the WPA2 passphrase (already validated)
 * @return {string} the profile name, for wiring into an interface
 * @internal
 */
func ensureWifiProfile(c as Client, profileName as string, password as string) {
    def attrs as map of string to string init {
        "mode": "dynamic-keys",
        "authentication-types": "wpa2-psk",
        "wpa2-pre-shared-key": $password
    };
    def id as string init idByName($c, WIRELESS_SECURITY_PATH, $profileName);
    if ($id == "") {
        $attrs["name"] = $profileName;
        add($c, WIRELESS_SECURITY_PATH, $attrs);
    } else {
        set($c, WIRELESS_SECURITY_PATH, $id, $attrs);
    }
    return $profileName;
}

/**
 * Fold a reply row into a WirelessInterface.
 *
 * @param {map of string to string} row an "/interface/wireless/print" row
 * @return {WirelessInterface} the typed wireless interface
 * @internal
 */
func wirelessFromRow(row as map of string to string) {
    return WirelessInterface{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        ssid: rowValue($row, "ssid"),
        mode: rowValue($row, "mode"),
        band: rowValue($row, "band"),
        frequency: rowValue($row, "frequency"),
        securityProfile: rowValue($row, "security-profile"),
        masterInterface: rowValue($row, "master-interface"),
        running: rowBool($row, "running"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * Fold a reply row into a WifiClient.
 *
 * @param {map of string to string} row a registration-table row
 * @return {WifiClient} the typed client entry
 * @internal
 */
func wifiClientFromRow(row as map of string to string) {
    return WifiClient{
        interfaceName: rowValue($row, "interface"),
        mac: rowValue($row, "mac-address"),
        signalStrength: rowValue($row, "signal-strength"),
        txRate: rowValue($row, "tx-rate"),
        rxRate: rowValue($row, "rx-rate"),
        uptime: rowValue($row, "uptime")
    };
}
