# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - IPv6: the stack switch, addresses, neighbor discovery.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the global IPv6 settings. */
export def const IPV6_SETTINGS_PATH as string init "/ipv6/settings";

/** RouterOS API path of the IPv6 address table. */
export def const IPV6_ADDRESS_PATH as string init "/ipv6/address";

/** RouterOS API path of the neighbor-discovery (router advertisement) table. */
export def const IPV6_ND_PATH as string init "/ipv6/nd";

/**
 * The router's global IPv6 settings.
 *
 * @field {bool} disabled       true when the whole IPv6 stack is switched off
 * @field {bool} forward        true when the router routes IPv6 between interfaces
 * @field {bool} acceptRouterAdvertisements true when the router configures
 *              itself from RAs it receives (the upstream-facing switch)
 * @field {bool} acceptRedirects true when ICMPv6 redirects are honoured
 * @field {int}  maxNeighborEntries the neighbor-cache cap
 */
export def struct Ipv6Settings {
    disabled as bool,
    forward as bool,
    acceptRouterAdvertisements as bool,
    acceptRedirects as bool,
    maxNeighborEntries as int
};

/**
 * One IPv6 address on an interface.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} address       the address in CIDR form
 * @field {string} interfaceName the interface it sits on
 * @field {bool}   advertise     true when the prefix is announced in RAs
 * @field {bool}   eui64         true when the host part is derived from the MAC
 * @field {bool}   linkLocal     true for a fe80::/10 address
 * @field {bool}   dynamic       true when RouterOS created it (SLAAC, DHCPv6-PD)
 * @field {bool}   disabled      true when switched off
 * @field {string} comment       free-text comment
 */
export def struct Ipv6Address {
    id as string,
    address as string,
    interfaceName as string,
    advertise as bool,
    eui64 as bool,
    linkLocal as bool,
    dynamic as bool,
    disabled as bool,
    comment as string
};

/**
 * One neighbor-discovery entry: how the router advertises itself on an
 * interface.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} interfaceName the interface, "all" for the default entry
 * @field {string} raInterval    the advertisement interval as reported
 * @field {string} raLifetime    how long clients treat this router as a default one
 * @field {bool}   managed       the M flag: clients should get addresses from DHCPv6
 * @field {bool}   otherConfig   the O flag: clients should get DNS etc. from DHCPv6
 * @field {bool}   advertiseDns  true when RAs carry the router's DNS servers
 * @field {bool}   disabled      true when switched off
 */
export def struct Ipv6Nd {
    id as string,
    interfaceName as string,
    raInterval as string,
    raLifetime as string,
    managed as bool,
    otherConfig as bool,
    advertiseDns as bool,
    disabled as bool
};

/**
 * Read the global IPv6 settings.
 *
 * @param {Client} c an open client
 * @return {Ipv6Settings} the current settings
 * @example
 *   def s as mt.Ipv6Settings init mt.ipv6Settings($c);
 *   if ($s.disabled) { io.printf("IPv6 is off on this router\n"); }
 */
export func ipv6Settings(c as Client) {
    return ipv6SettingsFromRow(singleRow($c, IPV6_SETTINGS_PATH));
}

/**
 * Switch the whole IPv6 stack off.
 *
 * The honest choice on a v4-only network: leaving IPv6 half-configured
 * is worse than not running it, because hosts still autoconfigure from
 * any RA on the wire and reach the internet around firewall rules that
 * only ever matched v4. Turning it off at the router closes that door.
 *
 * RouterOS applies this fully at the next reboot; the setting sticks
 * immediately, the running stack may not clear until then.
 *
 * @param {Client} c an open client
 * @example
 *   mt.disableIpv6($c);
 */
export func disableIpv6(c as Client) {
    apiRun($c, IPV6_SETTINGS_PATH + "/set", {"disable-ipv6": "yes"});
}

/**
 * Switch the IPv6 stack on.
 *
 * Takes effect after a reboot. Once IPv6 is up, remember that the v4
 * firewall does not filter it - the `/ipv6/firewall` chains are
 * separate, and an unfiltered v6 stack is a way into hosts you believe
 * are behind NAT.
 *
 * @param {Client} c an open client
 */
export func enableIpv6(c as Client) {
    apiRun($c, IPV6_SETTINGS_PATH + "/set", {"disable-ipv6": "no"});
}

/**
 * Turn IPv6 routing between interfaces on or off.
 *
 * @param {Client} c       an open client
 * @param {bool}   enabled true to route IPv6, false to keep it host-only
 */
export func setIpv6Forwarding(c as Client, enabled as bool) {
    apiRun($c, IPV6_SETTINGS_PATH + "/set", {"forward": boolWord($enabled)});
}

/**
 * Decide whether the router configures itself from router advertisements.
 *
 * Leave this on when the uplink hands out IPv6 by SLAAC; turn it off on
 * a router that should only use addresses you gave it.
 *
 * @param {Client} c       an open client
 * @param {bool}   enabled true to accept RAs
 */
export func setIpv6AcceptRouterAdvertisements(c as Client, enabled as bool) {
    apiRun($c, IPV6_SETTINGS_PATH + "/set", {"accept-router-advertisements": boolWord($enabled)});
}

/**
 * List the IPv6 addresses on the router.
 *
 * Includes the dynamic ones (link-local, SLAAC, DHCPv6-PD) - check
 * `dynamic` to tell them from what you configured.
 *
 * @param {Client} c an open client
 * @return {list of Ipv6Address} every IPv6 address
 */
export func ipv6Addresses(c as Client) {
    def rows as list of map of string to string init getAll($c, IPV6_ADDRESS_PATH);
    def out as list of Ipv6Address init [];
    for (def row in $rows) {
        $out[] = ipv6AddressFromRow($row);
    }
    return $out;
}

/**
 * List the IPv6 addresses on one interface.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface to filter on
 * @return {list of Ipv6Address} its addresses, empty when it has none
 * @throws {Error} kind "routeros" on an empty interface name
 */
export func ipv6AddressesOn(c as Client, interfaceName as string) {
    ensureName($interfaceName, "interface");
    def target as string init strings.trim($interfaceName);
    def out as list of Ipv6Address init [];
    for (def a in ipv6Addresses($c)) {
        if ($a.interfaceName == $target) {
            $out[] = $a;
        }
    }
    return $out;
}

/**
 * Give an interface a static IPv6 address.
 *
 * Write the address in CIDR form with the prefix the LAN actually uses -
 * `2001:db8:1::1/64`. A /64 is the smallest prefix SLAAC works on, so a
 * LAN wants /64 even though a router-to-router link can be tighter.
 *
 * @param {Client} c             an open client
 * @param {string} cidr          the address in CIDR form (e.g. "2001:db8:1::1/64")
 * @param {string} interfaceName the interface to put it on
 * @return {string} the RouterOS id of the new address
 * @throws {Error} kind "routeros" when the address is not valid IPv6 in
 *                 CIDR form, or the interface name is empty
 * @example
 *   mt.addIpv6Address($c, "2001:db8:1::1/64", "brlan");
 */
export func addIpv6Address(c as Client, cidr as string, interfaceName as string) {
    return addIpv6AddressWith($c, $cidr, $interfaceName, true, false);
}

/**
 * Give an interface a static IPv6 address, choosing how it is announced.
 *
 * `advertise` controls whether the prefix goes out in router
 * advertisements, which is what lets clients on that LAN configure
 * themselves by SLAAC - leave it true for a client network, false for a
 * router-to-router link where nothing should autoconfigure. `eui64`
 * derives the host part from the interface MAC, so the same call gives
 * every router a stable, distinct address inside the prefix.
 *
 * @param {Client} c             an open client
 * @param {string} cidr          the address in CIDR form
 * @param {string} interfaceName the interface to put it on
 * @param {bool}   advertise     announce the prefix in RAs
 * @param {bool}   eui64         derive the host part from the MAC
 * @return {string} the RouterOS id of the new address
 * @throws {Error} kind "routeros" on a bad address or interface name
 * @example
 *   mt.addIpv6AddressWith($c, "2001:db8:1::/64", "brlan", true, true);
 */
export func addIpv6AddressWith(
    c as Client,
    cidr as string,
    interfaceName as string,
    advertise as bool,
    eui64 as bool) {
    ensureIpv6Cidr($cidr);
    ensureName($interfaceName, "interface");
    return add(
        $c,
        IPV6_ADDRESS_PATH,
        {
            "address": strings.trim($cidr),
            "interface": strings.trim($interfaceName),
            "advertise": boolWord($advertise),
            "eui-64": boolWord($eui64)
        });
}

/**
 * Remove a static IPv6 address.
 *
 * Addresses RouterOS created itself (link-local, SLAAC, DHCPv6-PD) are
 * dynamic and cannot be removed this way - drop the thing that creates
 * them instead.
 *
 * @param {Client} c    an open client
 * @param {string} cidr the address in CIDR form, as it was added
 * @throws {Error} kind "routeros" when no such address is configured, or
 *                 when it is dynamic
 * @example
 *   mt.removeIpv6Address($c, "2001:db8:1::1/64");
 */
export func removeIpv6Address(c as Client, cidr as string) {
    ensureIpv6Cidr($cidr);
    def target as string init strings.trim($cidr);
    def rows as list of map of string to string init getAll($c, IPV6_ADDRESS_PATH);
    def row as map of string to string init findRowByField($rows, "address", $target);
    if (len($row) == 0) {
        raiseError("the IPv6 address " + $target + " is not configured on this router");
    }
    if (rowBool($row, "dynamic")) {
        raiseError("the IPv6 address " + $target +
            " is dynamic - remove what creates it, not the address");
    }
    remove($c, IPV6_ADDRESS_PATH, rowValue($row, ".id"));
}

/**
 * List the neighbor-discovery entries.
 *
 * @param {Client} c an open client
 * @return {list of Ipv6Nd} one entry per configured interface
 */
export func ipv6Nd(c as Client) {
    def rows as list of map of string to string init getAll($c, IPV6_ND_PATH);
    def out as list of Ipv6Nd init [];
    for (def row in $rows) {
        $out[] = ipv6NdFromRow($row);
    }
    return $out;
}

/**
 * Start advertising this router on an interface, so clients there can
 * configure themselves by SLAAC.
 *
 * Idempotent: updates the interface's existing entry when there is one,
 * creates it otherwise.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface to advertise on
 * @return {string} the RouterOS id of the entry
 * @throws {Error} kind "routeros" on an empty interface name
 * @example
 *   mt.advertiseIpv6On($c, "brlan");
 */
export func advertiseIpv6On(c as Client, interfaceName as string) {
    return setIpv6NdEntry($c, $interfaceName, {"disabled": "no"});
}

/**
 * Stop advertising this router on an interface.
 *
 * Clients keep the address they already built until the advertised
 * lifetime runs out; this stops new ones being handed a default route.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface to stop advertising on
 * @return {string} the RouterOS id of the entry
 * @throws {Error} kind "routeros" on an empty interface name
 */
export func stopAdvertisingIpv6On(c as Client, interfaceName as string) {
    return setIpv6NdEntry($c, $interfaceName, {"disabled": "yes"});
}

/**
 * Set the M and O flags an interface advertises.
 *
 * These tell clients where to get their configuration: `managed` (the M
 * flag) means "ask DHCPv6 for an address", `otherConfig` (the O flag)
 * means "build your own address, but ask DHCPv6 for DNS". Both false is
 * pure SLAAC, and is what a small network usually wants.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface to advertise on
 * @param {bool}   managed       the M flag
 * @param {bool}   otherConfig   the O flag
 * @return {string} the RouterOS id of the entry
 * @throws {Error} kind "routeros" on an empty interface name
 * @example
 *   mt.setIpv6NdFlags($c, "brlan", false, true);   # SLAAC + DHCPv6 for DNS
 */
export func setIpv6NdFlags(
    c as Client,
    interfaceName as string,
    managed as bool,
    otherConfig as bool) {
    return setIpv6NdEntry(
        $c,
        $interfaceName,
        {
            "managed-address-configuration": boolWord($managed),
            "other-configuration": boolWord($otherConfig)
        });
}

/**
 * Create or update the neighbor-discovery entry for an interface.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface the entry is for
 * @param {map of string to string} attrs the properties to write
 * @return {string} the RouterOS id of the entry
 * @throws {Error} kind "routeros" on an empty interface name
 * @internal
 */
func setIpv6NdEntry(c as Client, interfaceName as string, attrs as map of string to string) {
    ensureName($interfaceName, "interface");
    def target as string init strings.trim($interfaceName);
    def rows as list of map of string to string init getAll($c, IPV6_ND_PATH);
    def row as map of string to string init findRowByField($rows, "interface", $target);
    if (len($row) == 0) {
        def created as map of string to string init $attrs;
        $created["interface"] = $target;
        return add($c, IPV6_ND_PATH, $created);
    }
    def id as string init rowValue($row, ".id");
    set($c, IPV6_ND_PATH, $id, $attrs);
    return $id;
}

/**
 * Fold a reply row into Ipv6Settings.
 *
 * @param {map of string to string} row an "/ipv6/settings/print" row
 * @return {Ipv6Settings} the typed settings
 * @internal
 */
func ipv6SettingsFromRow(row as map of string to string) {
    return Ipv6Settings{
        disabled: rowBool($row, "disable-ipv6"),
        forward: rowBool($row, "forward"),
        acceptRouterAdvertisements: rowBool($row, "accept-router-advertisements"),
        acceptRedirects: rowBool($row, "accept-redirects"),
        maxNeighborEntries: rowInt($row, "max-neighbor-entries")
    };
}

/**
 * Fold a reply row into an Ipv6Address.
 *
 * @param {map of string to string} row an "/ipv6/address/print" row
 * @return {Ipv6Address} the typed address
 * @internal
 */
func ipv6AddressFromRow(row as map of string to string) {
    return Ipv6Address{
        id: rowValue($row, ".id"),
        address: rowValue($row, "address"),
        interfaceName: rowValue($row, "interface"),
        advertise: rowBool($row, "advertise"),
        eui64: rowBool($row, "eui-64"),
        linkLocal: rowBool($row, "link-local"),
        dynamic: rowBool($row, "dynamic"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * Fold a reply row into an Ipv6Nd.
 *
 * @param {map of string to string} row an "/ipv6/nd/print" row
 * @return {Ipv6Nd} the typed entry
 * @internal
 */
func ipv6NdFromRow(row as map of string to string) {
    return Ipv6Nd{
        id: rowValue($row, ".id"),
        interfaceName: rowValue($row, "interface"),
        raInterval: rowValue($row, "ra-interval"),
        raLifetime: rowValue($row, "ra-lifetime"),
        managed: rowBool($row, "managed-address-configuration"),
        otherConfig: rowBool($row, "other-configuration"),
        advertiseDns: rowBool($row, "advertise-dns"),
        disabled: rowBool($row, "disabled")
    };
}

/**
 * Validate an IPv6 address in CIDR form.
 *
 * Rejects a valid IPv4 CIDR with a message that says so, since passing
 * the v4 address by mistake is the likely slip here.
 *
 * @param {string} cidr the candidate (e.g. "2001:db8:1::1/64")
 * @throws {Error} kind "routeros" when it does not parse, or parses as IPv4
 * @internal
 */
func ensureIpv6Cidr(cidr as string) {
    ensureCidr($cidr);
    def net as ipnet.Network init ipnet.parse(strings.trim($cidr));
    if (ipnet.version($net.addr) != 6) {
        raiseError("\"" + $cidr + "\" is an IPv4 network - this call configures IPv6");
    }
}
