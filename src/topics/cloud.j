# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - MikroTik Cloud DDNS: a stable name for a dynamic address.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the MikroTik Cloud menu. */
export def const CLOUD_PATH as string init "/ip/cloud";

/**
 * The MikroTik Cloud DDNS state.
 *
 * @field {bool}   ddnsEnabled   true when the router keeps its cloud name updated
 * @field {string} dnsName       the router's name (<serial>.sn.mynetname.net),
 *                               "" until the first update completed
 * @field {string} publicAddress the public address the cloud last saw
 * @field {string} updateTime    when the name was last updated, as reported
 */
export def struct CloudStatus {
    ddnsEnabled as bool,
    dnsName as string,
    publicAddress as string,
    updateTime as string
};

/**
 * Read the cloud DDNS state.
 *
 * @param {Client} c an open client
 * @return {CloudStatus} the current state
 */
export func cloudStatus(c as Client) {
    return cloudFromRow(singleRow($c, CLOUD_PATH));
}

/**
 * Give the router a stable public DNS name (MikroTik Cloud DDNS).
 *
 * The router registers `<serial>.sn.mynetname.net` with MikroTik and
 * keeps it pointing at the current public address - the free answer to
 * a dynamic-IP WAN. The name is what road warriors dial
 * (`connectWireguard` endpoint, `enableLetsEncrypt` dns-name). An
 * update is forced immediately; the name usually resolves within a
 * minute.
 *
 * @param {Client} c an open client
 * @throws {Error} kind "mikrotik" when the router cannot reach the
 *                 cloud servers
 */
export func enableCloudDns(c as Client) {
    apiRun($c, CLOUD_PATH + "/set", {"ddns-enabled": "yes"});
    def none as map of string to string init {};
    apiRun($c, CLOUD_PATH + "/force-update", $none);
}

/**
 * Switch cloud DDNS off; the name stops updating.
 *
 * @param {Client} c an open client
 */
export func disableCloudDns(c as Client) {
    apiRun($c, CLOUD_PATH + "/set", {"ddns-enabled": "no"});
}

/**
 * The router's cloud DNS name, ready to dial.
 *
 * @param {Client} c an open client
 * @return {string} the name (e.g. "1234567890ab.sn.mynetname.net")
 * @throws {Error} kind "routeros" when no name is assigned yet
 */
export func routerDnsName(c as Client) {
    def status as CloudStatus init cloudStatus($c);
    if ($status.dnsName == "") {
        raiseError("no cloud DNS name assigned yet - enableCloudDns and give it a minute");
    }
    return $status.dnsName;
}

/**
 * Fold a reply row into the CloudStatus.
 *
 * @param {map of string to string} row the "/ip/cloud/print" row
 * @return {CloudStatus} the typed state
 * @internal
 */
func cloudFromRow(row as map of string to string) {
    return CloudStatus{
        ddnsEnabled: rowBool($row, "ddns-enabled"),
        dnsName: rowValue($row, "dns-name"),
        publicAddress: rowValue($row, "public-address"),
        updateTime: rowValue($row, "update-time")
    };
}
