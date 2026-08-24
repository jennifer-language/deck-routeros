# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - DNS resolver settings, static entries, and the cache.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the DNS resolver menu. */
export def const DNS_PATH as string init "/ip/dns";

/** RouterOS API path of the static DNS entry list. */
export def const DNS_STATIC_PATH as string init "/ip/dns/static";

/** RouterOS API path of the DNS adlist (blocklists, RouterOS 7.15+). */
export def const DNS_ADLIST_PATH as string init "/ip/dns/adlist";

/** RouterOS API path of the DNS cache (what the resolver knows right now). */
export def const DNS_CACHE_PATH as string init "/ip/dns/cache";

/**
 * One DNS cache record: what the resolver would answer right now.
 *
 * @field {string} id       internal RouterOS id
 * @field {string} name     the DNS name the record answers for
 * @field {string} kind     record type ("A", "AAAA", "CNAME", ...)
 * @field {string} data     the answer (an address for A/AAAA, a name for CNAME)
 * @field {string} ttl      time until the record expires from the cache
 * @field {bool}   isStatic true when it comes from a static entry (never expires)
 */
export def struct DnsCacheEntry {
    id as string,
    name as string,
    kind as string,
    data as string,
    ttl as string,
    isStatic as bool
};

/**
 * The DNS resolver configuration of the router.
 *
 * @field {string} servers             upstream servers, comma-separated
 * @field {bool}   allowRemoteRequests true when the router answers DNS for its clients
 * @field {string} cacheSize           resolver cache size as reported
 * @field {string} cacheUsed           resolver cache usage as reported
 */
export def struct DnsSettings {
    servers as string,
    allowRemoteRequests as bool,
    cacheSize as string,
    cacheUsed as string
};

/**
 * One static DNS entry (a local name that resolves to a fixed address).
 *
 * @field {string} id       internal RouterOS id
 * @field {string} name     the DNS name (e.g. "nas.lan")
 * @field {string} address  the IP address it resolves to
 * @field {string} ttl      time-to-live as reported (e.g. "1d")
 * @field {bool}   disabled true when the entry is switched off
 * @field {string} comment  free-text comment, "" when unset
 */
export def struct DnsEntry {
    id as string,
    name as string,
    address as string,
    ttl as string,
    disabled as bool,
    comment as string
};

/**
 * Read the router's DNS resolver configuration.
 *
 * @param {Client} c an open client
 * @return {DnsSettings} the resolver state
 */
export func dnsSettings(c as Client) {
    return dnsSettingsFromRow(singleRow($c, DNS_PATH));
}

/**
 * Point the router's resolver at upstream DNS servers.
 *
 * @param {Client} c       an open client
 * @param {string} servers one or more server addresses, comma-separated
 *                         (e.g. "1.1.1.1,9.9.9.9"); spaces are tolerated
 * @throws {Error} kind "routeros" when an entry is not an IP address
 */
export func setDnsServers(c as Client, servers as string) {
    apiRun($c, DNS_PATH + "/set", {"servers": normalizedAddressList($servers)});
}

/**
 * Let (or stop letting) the router answer DNS queries from its clients.
 *
 * Switch this on when DHCP clients use the router as their DNS server.
 * Caution: it answers on ALL interfaces - on an internet-facing router,
 * block UDP/TCP port 53 on the WAN side (see `firewallRule`) or you are
 * running an open resolver.
 *
 * @param {Client} c     an open client
 * @param {bool}   allow true to answer client queries, false to refuse them
 */
export func allowRemoteDnsRequests(c as Client, allow as bool) {
    apiRun($c, DNS_PATH + "/set", {"allow-remote-requests": boolWord($allow)});
}

/**
 * List the static DNS entries (local names the router resolves itself).
 *
 * @param {Client} c an open client
 * @return {list of DnsEntry} all static entries
 */
export func dnsStaticEntries(c as Client) {
    def rows as list of map of string to string init getAll($c, DNS_STATIC_PATH);
    def out as list of DnsEntry init [];
    for (def row in $rows) {
        $out[] = dnsEntryFromRow($row);
    }
    return $out;
}

/**
 * Add a static DNS entry: a local name that resolves to a fixed address.
 *
 * Clients only see it when they use the router as their DNS server
 * (see `allowRemoteDnsRequests`).
 *
 * @param {Client} c       an open client
 * @param {string} name    the DNS name (e.g. "nas.lan")
 * @param {string} address the IP address it should resolve to
 * @return {string} the RouterOS id of the new entry
 * @throws {Error} kind "routeros" on an empty name or malformed address
 */
export func addDnsEntry(c as Client, name as string, address as string) {
    ensureName($name, "DNS entry");
    ensureIpAddress($address);
    return add($c, DNS_STATIC_PATH, {"name": $name, "address": $address});
}

/**
 * Remove a static DNS entry by its name.
 *
 * @param {Client} c    an open client
 * @param {string} name the DNS name of the entry
 * @throws {Error} kind "routeros" when no entry has that name
 */
export func removeDnsEntry(c as Client, name as string) {
    remove($c, DNS_STATIC_PATH, requiredId($c, DNS_STATIC_PATH, $name, "DNS entry"));
}

/**
 * Read the whole DNS cache: everything the resolver knows right now.
 *
 * On a busy router this is large - prefer `dnsCacheFor` /
 * `resolvedAddresses` for one name. Cache fill level is in
 * `dnsSettings` (`cacheUsed` / `cacheSize`).
 *
 * @param {Client} c an open client
 * @return {list of DnsCacheEntry} all cached records
 */
export func dnsCache(c as Client) {
    def rows as list of map of string to string init getAll($c, DNS_CACHE_PATH);
    def out as list of DnsCacheEntry init [];
    for (def row in $rows) {
        $out[] = dnsCacheEntryFromRow($row);
    }
    return $out;
}

/**
 * The cached records for one name (case-insensitive).
 *
 * Answers "what would the router resolve this to right now" - several
 * records are normal (A + AAAA, or a CNAME chain). An empty result
 * means the router has not resolved that name recently.
 *
 * @param {Client} c    an open client
 * @param {string} name the DNS name to look up in the cache
 * @return {list of DnsCacheEntry} the matching records, possibly empty
 * @throws {Error} kind "routeros" on an empty or spaced name
 */
export func dnsCacheFor(c as Client, name as string) {
    ensureName($name, "DNS");
    def rows as list of map of string to string init getAll($c, DNS_CACHE_PATH);
    def hits as list of map of string to string init cacheRowsForName($rows, $name);
    def out as list of DnsCacheEntry init [];
    for (def row in $hits) {
        $out[] = dnsCacheEntryFromRow($row);
    }
    return $out;
}

/**
 * The IP addresses the cache currently holds for a name (A and AAAA
 * records only - CNAMEs and other types are skipped).
 *
 * @param {Client} c    an open client
 * @param {string} name the DNS name
 * @return {list of string} the cached addresses, possibly empty
 * @throws {Error} kind "routeros" on an empty or spaced name
 * @example
 *   def addrs as list of string init mt.resolvedAddresses($c, "example.org");
 *   for (def a in $addrs) { io.printf("cached: %s\n", $a); }
 */
export func resolvedAddresses(c as Client, name as string) {
    ensureName($name, "DNS");
    def rows as list of map of string to string init getAll($c, DNS_CACHE_PATH);
    return addressesFromCacheRows($rows, $name);
}

/**
 * Empty the DNS cache; the resolver re-asks upstream for everything.
 *
 * The classic fix for "it still resolves to the old address" after a
 * DNS change - and the right follow-up to `setDnsServers`. Static
 * entries survive (they are configuration, not cache).
 *
 * @param {Client} c an open client
 */
export func flushDnsCache(c as Client) {
    def none as map of string to string init {};
    apiRun($c, DNS_CACHE_PATH + "/flush", $none);
}

/**
 * Fold a reply row into the DnsSettings.
 *
 * @param {map of string to string} row the "/ip/dns/print" row
 * @return {DnsSettings} the typed resolver state
 * @internal
 */
func dnsSettingsFromRow(row as map of string to string) {
    return DnsSettings{
        servers: rowValue($row, "servers"),
        allowRemoteRequests: rowBool($row, "allow-remote-requests"),
        cacheSize: rowValue($row, "cache-size"),
        cacheUsed: rowValue($row, "cache-used")
    };
}

/**
 * Fold a reply row into a DnsEntry.
 *
 * @param {map of string to string} row an "/ip/dns/static/print" row
 * @return {DnsEntry} the typed entry
 * @internal
 */
func dnsEntryFromRow(row as map of string to string) {
    return DnsEntry{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        address: rowValue($row, "address"),
        ttl: rowValue($row, "ttl"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * The cache rows answering for a name, compared case-insensitively
 * (DNS names are).
 *
 * @param {list of map of string to string} rows "/ip/dns/cache/print" rows
 * @param {string} name the name to match
 * @return {list of map of string to string} the matching rows, in order
 * @internal
 */
func cacheRowsForName(rows as list of map of string to string, name as string) {
    def wanted as string init strings.lower(strings.trim($name));
    def out as list of map of string to string init [];
    for (def row in $rows) {
        if (strings.lower(rowValue($row, "name")) == $wanted) {
            $out[] = $row;
        }
    }
    return $out;
}

/**
 * The cached A/AAAA addresses for a name.
 *
 * @param {list of map of string to string} rows "/ip/dns/cache/print" rows
 * @param {string} name the name to match (case-insensitive)
 * @return {list of string} the address record data, in cache order
 * @internal
 */
func addressesFromCacheRows(rows as list of map of string to string, name as string) {
    def hits as list of map of string to string init cacheRowsForName($rows, $name);
    def out as list of string init [];
    for (def row in $hits) {
        def kind as string init rowValue($row, "type");
        if ($kind == "A" or $kind == "AAAA") {
            $out[] = rowValue($row, "data");
        }
    }
    return $out;
}

/**
 * Fold a reply row into a DnsCacheEntry.
 *
 * @param {map of string to string} row an "/ip/dns/cache/print" row
 * @return {DnsCacheEntry} the typed record
 * @internal
 */
func dnsCacheEntryFromRow(row as map of string to string) {
    return DnsCacheEntry{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        kind: rowValue($row, "type"),
        data: rowValue($row, "data"),
        ttl: rowValue($row, "ttl"),
        isStatic: rowBool($row, "static")
    };
}

/**
 * One DNS adlist: a hosts/blocklist the resolver applies (v7.15+).
 *
 * @field {string} id        internal RouterOS id
 * @field {string} url       the blocklist URL, "" for a local-file list
 * @field {string} matchCount how many names it currently blocks
 * @field {bool}   disabled  true when switched off
 */
export def struct DnsAdlist {
    id as string,
    url as string,
    matchCount as string,
    disabled as bool
};

/**
 * List the DNS adlists (blocklists).
 *
 * @param {Client} c an open client
 * @return {list of DnsAdlist} all adlists
 */
export func dnsAdlists(c as Client) {
    def rows as list of map of string to string init getAll($c, DNS_ADLIST_PATH);
    def out as list of DnsAdlist init [];
    for (def row in $rows) {
        $out[] = dnsAdlistFromRow($row);
    }
    return $out;
}

/**
 * Add a DNS blocklist by URL (router-wide ad / malware blocking).
 *
 * RouterOS 7.15+ downloads the hosts-format list and answers 0.0.0.0
 * for every name on it, for every client using the router as resolver
 * (see `allowRemoteDnsRequests`). Needs a chunk of RAM for large lists.
 * Idempotent by URL. After adding, RouterOS loads it on the next
 * refresh (or `mt.getAll` triggers none - reload via the generic verbs
 * if needed).
 *
 * @param {Client} c   an open client
 * @param {string} url the blocklist URL (https, hosts format)
 * @return {string} the RouterOS id of the (new or existing) adlist
 * @throws {Error} kind "routeros" on an empty or non-http URL
 * @example
 *   mt.allowRemoteDnsRequests($c, true);
 *   mt.addAdlist($c, "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts");
 */
export func addAdlist(c as Client, url as string) {
    def target as string init strings.trim($url);
    if ($target == "" or not strings.startsWith($target, "http")) {
        raiseError("the adlist URL must be an http(s) URL");
    }
    def rows as list of map of string to string init getAll($c, DNS_ADLIST_PATH);
    def existing as map of string to string init findRowByField($rows, "url", $target);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    return add($c, DNS_ADLIST_PATH, {"url": $target});
}

/**
 * Remove a DNS blocklist.
 *
 * @param {Client} c   an open client
 * @param {string} url the blocklist URL
 * @throws {Error} kind "routeros" when no adlist has that URL
 */
export func removeAdlist(c as Client, url as string) {
    def rows as list of map of string to string init getAll($c, DNS_ADLIST_PATH);
    def row as map of string to string init findRowByField($rows, "url", strings.trim($url));
    if (len($row) == 0) {
        raiseError("no adlist with the URL \"" + $url + "\" was found");
    }
    remove($c, DNS_ADLIST_PATH, rowValue($row, ".id"));
}

/**
 * Fold a reply row into a DnsAdlist.
 *
 * @param {map of string to string} row an "/ip/dns/adlist/print" row
 * @return {DnsAdlist} the typed adlist
 * @internal
 */
func dnsAdlistFromRow(row as map of string to string) {
    return DnsAdlist{
        id: rowValue($row, ".id"),
        url: rowValue($row, "url"),
        matchCount: rowValue($row, "match-count"),
        disabled: rowBool($row, "disabled")
    };
}
