# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - SNMP: plug the router into your monitoring.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the SNMP settings menu. */
export def const SNMP_PATH as string init "/snmp";

/** RouterOS API path of the SNMP community list. */
export def const SNMP_COMMUNITY_PATH as string init "/snmp/community";

/**
 * The SNMP agent settings.
 *
 * @field {bool}   enabled  true when the agent answers queries
 * @field {string} contact  the contact string monitoring systems display
 * @field {string} location the location string monitoring systems display
 */
export def struct SnmpSettings {
    enabled as bool,
    contact as string,
    location as string
};

/**
 * One SNMP community: a name that grants (read) access.
 *
 * @field {string} id          internal RouterOS id
 * @field {string} name        the community string (acts like a password!)
 * @field {string} addresses   networks allowed to query, "" for anywhere
 * @field {bool}   readAccess  true when reading is allowed
 * @field {bool}   writeAccess true when writing is allowed (avoid)
 * @field {bool}   disabled    true when switched off
 */
export def struct SnmpCommunity {
    id as string,
    name as string,
    addresses as string,
    readAccess as bool,
    writeAccess as bool,
    disabled as bool
};

/**
 * Read the SNMP agent settings.
 *
 * @param {Client} c an open client
 * @return {SnmpSettings} the agent state
 */
export func snmpSettings(c as Client) {
    return snmpFromRow(singleRow($c, SNMP_PATH));
}

/**
 * List the SNMP communities.
 *
 * @param {Client} c an open client
 * @return {list of SnmpCommunity} all communities (including the
 *         default "public" - consider disabling it)
 */
export func snmpCommunities(c as Client) {
    def rows as list of map of string to string init getAll($c, SNMP_COMMUNITY_PATH);
    def out as list of SnmpCommunity init [];
    for (def row in $rows) {
        $out[] = snmpCommunityFromRow($row);
    }
    return $out;
}

/**
 * Enable SNMP for a monitoring system, read-only and restricted.
 *
 * Creates (or updates) a read-only community and switches the agent
 * on. SNMP v2c sends the community string in cleartext, so treat it
 * like a password anyway: pick a non-obvious name, restrict the
 * sources, and consider disabling the default "public" community
 * (generic `disable` on SNMP_COMMUNITY_PATH). Idempotent.
 *
 * @param {Client} c         an open client
 * @param {string} community the community string your monitoring uses
 * @param {string} addresses allowed sources: IPs/CIDRs, comma-separated;
 *                           "" allows anywhere (not recommended)
 * @return {string} the RouterOS id of the community
 * @throws {Error} kind "routeros" on a bad community name or address list
 * @example
 *   mt.enableSnmp($c, "mon4711", "10.0.9.0/24");
 *   mt.setSnmpInfo($c, "noc@example.org", "rack 3, office Berlin");
 */
export func enableSnmp(c as Client, community as string, addresses as string) {
    ensureName($community, "SNMP community");
    def allowed as string init "";
    if (strings.trim($addresses) != "") {
        $allowed = normalizedUserAddress($addresses);
    }
    def attrs as map of string to string init {
        "addresses": $allowed,
        "read-access": "yes",
        "write-access": "no"
    };
    def id as string init idByName($c, SNMP_COMMUNITY_PATH, $community);
    if ($id == "") {
        $attrs["name"] = $community;
        $id = add($c, SNMP_COMMUNITY_PATH, $attrs);
    } else {
        set($c, SNMP_COMMUNITY_PATH, $id, $attrs);
    }
    apiRun($c, SNMP_PATH + "/set", {"enabled": "yes"});
    return $id;
}

/**
 * Set the contact and location strings monitoring systems display.
 *
 * @param {Client} c        an open client
 * @param {string} contact  who to call (e.g. "noc@example.org")
 * @param {string} location where the box is (e.g. "rack 3, office Berlin")
 */
export func setSnmpInfo(c as Client, contact as string, location as string) {
    apiRun($c, SNMP_PATH + "/set", {"contact": $contact, "location": $location});
}

/**
 * Switch the SNMP agent off.
 *
 * @param {Client} c an open client
 */
export func disableSnmp(c as Client) {
    apiRun($c, SNMP_PATH + "/set", {"enabled": "no"});
}

/**
 * Fold a reply row into the SnmpSettings.
 *
 * @param {map of string to string} row the "/snmp/print" row
 * @return {SnmpSettings} the typed settings
 * @internal
 */
func snmpFromRow(row as map of string to string) {
    return SnmpSettings{
        enabled: rowBool($row, "enabled"),
        contact: rowValue($row, "contact"),
        location: rowValue($row, "location")
    };
}

/**
 * Fold a reply row into a SnmpCommunity.
 *
 * @param {map of string to string} row a "/snmp/community/print" row
 * @return {SnmpCommunity} the typed community
 * @internal
 */
func snmpCommunityFromRow(row as map of string to string) {
    return SnmpCommunity{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        addresses: rowValue($row, "addresses"),
        readAccess: rowBool($row, "read-access"),
        writeAccess: rowBool($row, "write-access"),
        disabled: rowBool($row, "disabled")
    };
}
