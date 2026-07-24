# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - IP addresses on interfaces.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the IP address list. */
export def const IP_ADDRESS_PATH as string init "/ip/address";

/**
 * One IP address assigned to an interface.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} address       the address with prefix (e.g. "192.168.88.1/24")
 * @field {string} network       the network the prefix implies (e.g. "192.168.88.0")
 * @field {string} interfaceName interface the address sits on
 * @field {bool}   dynamic       true when DHCP/PPP assigned it (not removable)
 * @field {bool}   disabled      true when the address is switched off
 * @field {string} comment       free-text comment, "" when unset
 */
export def struct IpAddress {
    id as string,
    address as string,
    network as string,
    interfaceName as string,
    dynamic as bool,
    disabled as bool,
    comment as string
};

/**
 * List every IP address on the router.
 *
 * @param {Client} c an open client
 * @return {list of IpAddress} all addresses, static and dynamic
 */
export func ipAddresses(c as Client) {
    def rows as list of map of string to string init getAll($c, IP_ADDRESS_PATH);
    def out as list of IpAddress init [];
    for (def row in $rows) {
        $out[] = ipAddressFromRow($row);
    }
    return $out;
}

/**
 * Give an interface an IP address.
 *
 * @param {Client} c             an open client
 * @param {string} address       the address WITH prefix length (e.g.
 *                               "192.168.88.1/24" - the prefix tells the
 *                               router how large the network is)
 * @param {string} interfaceName interface (or bridge) to put it on
 * @return {string} the RouterOS id of the new address
 * @throws {Error} kind "routeros" on a malformed address, a missing
 *                 prefix, or an unknown interface
 */
export func addIpAddress(c as Client, address as string, interfaceName as string) {
    ensureCidr($address);
    requiredId($c, INTERFACE_PATH, $interfaceName, "interface");
    return add($c, IP_ADDRESS_PATH, {"address": $address, "interface": $interfaceName});
}

/**
 * Remove an IP address from whatever interface it sits on.
 *
 * @param {Client} c       an open client
 * @param {string} address the address with prefix, exactly as listed
 *                         (e.g. "192.168.88.1/24")
 * @throws {Error} kind "routeros" when the router has no such address
 */
export func removeIpAddress(c as Client, address as string) {
    def rows as list of map of string to string init getAll($c, IP_ADDRESS_PATH);
    def row as map of string to string init findRowByField($rows, "address", $address);
    if (len($row) == 0) {
        raiseError("the address \"" + $address + "\" is not configured on the router");
    }
    remove($c, IP_ADDRESS_PATH, rowValue($row, ".id"));
}

/**
 * Fold a reply row into an IpAddress.
 *
 * @param {map of string to string} row an "/ip/address/print" row
 * @return {IpAddress} the typed address
 * @internal
 */
func ipAddressFromRow(row as map of string to string) {
    return IpAddress{
        id: rowValue($row, ".id"),
        address: rowValue($row, "address"),
        network: rowValue($row, "network"),
        interfaceName: rowValue($row, "interface"),
        dynamic: rowBool($row, "dynamic"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
