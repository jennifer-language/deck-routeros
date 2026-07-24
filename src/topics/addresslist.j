# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - firewall address lists: named sets of addresses.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the firewall address lists. */
export def const ADDRESS_LIST_PATH as string init "/ip/firewall/address-list";

/**
 * One entry of a firewall address list.
 *
 * @field {string} id       internal RouterOS id
 * @field {string} listName the list the entry belongs to (e.g. "blocklist")
 * @field {string} address  an IP, a CIDR network, or a DNS name (RouterOS
 *                          resolves names and keeps them updated)
 * @field {string} timeout  remaining lifetime, "" for a permanent entry
 * @field {bool}   dynamic  true when something else created it (e.g. a
 *                          firewall rule with add-src-to-address-list)
 * @field {bool}   disabled true when the entry is switched off
 * @field {string} comment  free-text comment, "" when unset
 */
export def struct AddressListEntry {
    id as string,
    listName as string,
    address as string,
    timeout as string,
    dynamic as bool,
    disabled as bool,
    comment as string
};

/**
 * The names of all address lists on the router.
 *
 * @param {Client} c an open client
 * @return {list of string} distinct list names, in first-seen order
 */
export func addressLists(c as Client) {
    def rows as list of map of string to string init getAll($c, ADDRESS_LIST_PATH);
    return distinctLists($rows);
}

/**
 * The entries of one address list.
 *
 * @param {Client} c        an open client
 * @param {string} listName the list to read (e.g. "blocklist")
 * @return {list of AddressListEntry} the list's entries (empty when unknown)
 */
export func addressListEntries(c as Client, listName as string) {
    def rows as list of map of string to string init getAll($c, ADDRESS_LIST_PATH);
    def out as list of AddressListEntry init [];
    for (def row in $rows) {
        if (rowValue($row, "list") == $listName) {
            $out[] = addressListEntryFromRow($row);
        }
    }
    return $out;
}

/**
 * Put an address on a list (permanently).
 *
 * The list is created implicitly with its first entry. The address may
 * be a single IP ("203.0.113.7"), a network ("203.0.113.0/24"), or a
 * DNS name ("bad.example.org" - RouterOS resolves it and tracks
 * changes). Idempotent: if the list already holds that address, the
 * existing entry's id is returned.
 *
 * @param {Client} c        an open client
 * @param {string} listName the list (e.g. "blocklist", "vpnusers")
 * @param {string} address  IP, CIDR, or DNS name
 * @param {string} comment  friendly note ("" for none)
 * @return {string} the RouterOS id of the (new or existing) entry
 * @throws {Error} kind "routeros" on a bad list name or address
 * @example
 *   mt.addToAddressList($c, "blocklist", "203.0.113.7", "ssh scanner");
 *   mt.dropAddressList($c, "blocklist", mt.CHAIN_INPUT, "drop blocklisted");
 */
export func addToAddressList(c as Client, listName as string, address as string, comment as string) {
    ensureName($listName, "address list");
    def entry as string init strings.trim($address);
    ensureListAddress($entry);
    def rows as list of map of string to string init getAll($c, ADDRESS_LIST_PATH);
    def existing as map of string to string init findAddressListRow($rows, $listName, $entry);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    def attrs as map of string to string init {"list": $listName, "address": $entry};
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, ADDRESS_LIST_PATH, $attrs);
}

/**
 * Put an address on a list temporarily; it expires by itself.
 *
 * Useful for penalties ("blocked for a day") that need no cleanup job.
 *
 * @param {Client} c        an open client
 * @param {string} listName the list
 * @param {string} address  IP, CIDR, or DNS name
 * @param {string} timeout  lifetime: "30m", "1d", "1w", or "HH:MM:SS"
 * @param {string} comment  friendly note ("" for none)
 * @return {string} the RouterOS id of the new entry
 * @throws {Error} kind "routeros" on a bad list name, address, or timeout
 */
export func addToAddressListTimed(c as Client, listName as string, address as string, timeout as string, comment as string) {
    ensureName($listName, "address list");
    def entry as string init strings.trim($address);
    ensureListAddress($entry);
    def ttl as string init strings.trim($timeout);
    ensureSchedulerInterval($ttl);
    def attrs as map of string to string init
        {"list": $listName, "address": $entry, "timeout": $ttl};
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, ADDRESS_LIST_PATH, $attrs);
}

/**
 * Take one address off a list.
 *
 * @param {Client} c        an open client
 * @param {string} listName the list
 * @param {string} address  the address exactly as listed
 * @throws {Error} kind "routeros" when the list has no such entry
 */
export func removeFromAddressList(c as Client, listName as string, address as string) {
    def rows as list of map of string to string init getAll($c, ADDRESS_LIST_PATH);
    def row as map of string to string init findAddressListRow($rows, $listName, strings.trim($address));
    if (len($row) == 0) {
        raiseError("the list \"" + $listName + "\" has no entry \"" + $address + "\"");
    }
    remove($c, ADDRESS_LIST_PATH, rowValue($row, ".id"));
}

/**
 * Empty an address list: remove every static entry.
 *
 * Dynamic entries (added by firewall rules or with a timeout by other
 * software) are left alone - they expire or are managed by whatever
 * created them.
 *
 * @param {Client} c        an open client
 * @param {string} listName the list to empty
 * @throws {Error} kind "routeros" when the list has no static entries
 */
export func clearAddressList(c as Client, listName as string) {
    def rows as list of map of string to string init getAll($c, ADDRESS_LIST_PATH);
    def cleared as int init 0;
    for (def row in $rows) {
        if (rowValue($row, "list") == $listName and not rowBool($row, "dynamic")) {
            remove($c, ADDRESS_LIST_PATH, rowValue($row, ".id"));
            $cleared = $cleared + 1;
        }
    }
    if ($cleared == 0) {
        raiseError("the address list \"" + $listName + "\" has no static entries");
    }
}

/**
 * Drop all traffic from the members of an address list (one firewall
 * rule referencing the whole list).
 *
 * The point of address lists: the rule stays, the list changes. Add and
 * remove members with `addToAddressList` / `removeFromAddressList`
 * without ever touching the firewall again. The rule carries `comment`
 * as its handle for the *ByComment helpers.
 *
 * @param {Client} c        an open client
 * @param {string} listName the list whose members are dropped
 * @param {string} chain    where: CHAIN_INPUT (protect the router) or
 *                          CHAIN_FORWARD (protect the networks behind it)
 * @param {string} comment  handle for the rule (e.g. "drop blocklisted")
 * @return {string} the RouterOS id of the new rule
 * @throws {Error} kind "routeros" on a bad list or chain
 */
export func dropAddressList(c as Client, listName as string, chain as string, comment as string) {
    ensureName($listName, "address list");
    def r as FirewallRule init firewallRule($chain, ACTION_DROP);
    $r = withSrcAddressList($r, $listName);
    $r = withComment($r, $comment);
    return addFirewallRule($c, $r);
}

/**
 * Find the entry of a list holding an address.
 *
 * @param {list of map of string to string} rows address-list rows
 * @param {string} listName the list to search
 * @param {string} address  the address to look for
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func findAddressListRow(rows as list of map of string to string, listName as string, address as string) {
    for (def row in $rows) {
        if (rowValue($row, "list") == $listName and rowValue($row, "address") == $address) {
            return $row;
        }
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Distinct list names, in first-seen order.
 *
 * @param {list of map of string to string} rows address-list rows
 * @return {list of string} the list names, deduplicated
 * @internal
 */
func distinctLists(rows as list of map of string to string) {
    def out as list of string init [];
    for (def row in $rows) {
        def name as string init rowValue($row, "list");
        if ($name != "" and not lists.contains($out, $name)) {
            $out[] = $name;
        }
    }
    return $out;
}

/**
 * Validate an address-list address: IP, CIDR network, or DNS name.
 *
 * @param {string} address the candidate (already trimmed)
 * @throws {Error} kind "routeros" on an empty or malformed value
 * @internal
 */
func ensureListAddress(address as string) {
    if (strings.contains($address, "/")) {
        ensureCidr($address);
        return;
    }
    if (isIpAddress($address)) {
        return;
    }
    ensureName($address, "address-list");
}

/**
 * Fold a reply row into an AddressListEntry.
 *
 * @param {map of string to string} row an "/ip/firewall/address-list/print" row
 * @return {AddressListEntry} the typed entry
 * @internal
 */
func addressListEntryFromRow(row as map of string to string) {
    return AddressListEntry{
        id: rowValue($row, ".id"),
        listName: rowValue($row, "list"),
        address: rowValue($row, "address"),
        timeout: rowValue($row, "timeout"),
        dynamic: rowBool($row, "dynamic"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
