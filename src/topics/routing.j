# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - static routes.
# Spliced into routeros.j via include - not a standalone module.

/**
 * RouterOS API path of the route list.
 *
 * Static routes live under "/ip/route"; RouterOS's "/routing" menu holds
 * the dynamic protocols (OSPF, BGP) and their filters.
 */
export def const ROUTE_PATH as string init "/ip/route";

/** The destination that matches everything: the default route. */
export def const DEFAULT_ROUTE as string init "0.0.0.0/0";

/**
 * RouterOS API path of the policy routing rules (RouterOS v7).
 *
 * RouterOS 6 kept these under "/ip/route/rule" - drive that with the
 * generic verbs on old routers.
 */
export def const ROUTING_RULE_PATH as string init "/routing/rule";

/** RouterOS API path of the routing tables (RouterOS v7). */
export def const ROUTING_TABLE_PATH as string init "/routing/table";

/**
 * One policy routing rule: who looks routes up in which table.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} srcAddress    whose traffic the rule matches, "" for any
 * @field {string} dstAddress    matched destination, "" for any
 * @field {string} interfaceName matched incoming interface, "" for any
 * @field {string} action        "lookup" (fall back to main),
 *                               "lookup-only-in-table" (strict), ...
 * @field {string} table         the routing table consulted
 * @field {bool}   disabled      true when switched off
 * @field {string} comment       free-text comment, "" when unset
 */
export def struct RoutingRule {
    id as string,
    srcAddress as string,
    dstAddress as string,
    interfaceName as string,
    action as string,
    table as string,
    disabled as bool,
    comment as string
};

/**
 * One route: where to send traffic for a destination network.
 *
 * @field {string} id           internal RouterOS id
 * @field {string} dstAddress   destination network as CIDR ("0.0.0.0/0" is the default route)
 * @field {string} gateway      next hop: an IP address or an interface name
 * @field {string} distance     route preference; lower wins (RouterOS default "1")
 * @field {string} routingTable routing table the route lives in ("main" normally)
 * @field {bool}   active       true when the route is currently usable
 * @field {bool}   dynamic      true when a protocol or service created it
 *                              (dynamic routes cannot be removed by hand)
 * @field {bool}   disabled     true when the route is switched off
 * @field {string} comment      free-text comment, "" when unset
 */
export def struct Route {
    id as string,
    dstAddress as string,
    gateway as string,
    distance as string,
    routingTable as string,
    active as bool,
    dynamic as bool,
    disabled as bool,
    comment as string
};

/**
 * List every route the router knows: static, connected, and dynamic.
 *
 * Filter on the `dynamic` field to see only the hand-made ones.
 *
 * @param {Client} c an open client
 * @return {list of Route} all routes
 */
export func routes(c as Client) {
    def rows as list of map of string to string init getAll($c, ROUTE_PATH);
    def out as list of Route init [];
    for (def row in $rows) {
        $out[] = routeFromRow($row);
    }
    return $out;
}

/**
 * Add a static route: send traffic for a network to a next hop.
 *
 * @param {Client} c          an open client
 * @param {string} dstAddress destination network as CIDR (e.g. "10.20.0.0/16")
 * @param {string} gateway    next hop: the neighbouring router's IP
 *                            address, or an interface name for
 *                            point-to-point links
 * @param {string} comment    friendly note ("" for none)
 * @return {string} the RouterOS id of the new route
 * @throws {Error} kind "routeros" on a malformed destination, or when
 *                 `gateway` is neither an IP address nor an existing interface
 * @example
 *   mt.addRoute($c, "10.20.0.0/16", "192.168.88.254", "to branch office");
 */
export func addRoute(c as Client, dstAddress as string, gateway as string, comment as string) {
    return routeAdd($c, $dstAddress, $gateway, 0, $comment);
}

/**
 * Add a static route with an explicit distance (route preference).
 *
 * Lower distance wins; RouterOS's default for a static route is 1. A
 * second route to the same destination with a higher distance is a
 * backup that takes over when the preferred one fails.
 *
 * @param {Client} c          an open client
 * @param {string} dstAddress destination network as CIDR
 * @param {string} gateway    next hop: IP address or interface name
 * @param {int}    distance   route preference, 1-255
 * @param {string} comment    friendly note ("" for none)
 * @return {string} the RouterOS id of the new route
 * @throws {Error} kind "routeros" on a malformed destination, gateway,
 *                 or a distance outside 1-255
 */
export func addRouteWithDistance(c as Client, dstAddress as string, gateway as string, distance as int, comment as string) {
    ensureDistance($distance);
    return routeAdd($c, $dstAddress, $gateway, $distance, $comment);
}

/**
 * Add the default route: where all traffic without a better match goes.
 *
 * This is "the internet is that way" - the gateway is normally your
 * ISP's router.
 *
 * @param {Client} c       an open client
 * @param {string} gateway next hop: IP address or interface name
 * @param {string} comment friendly note ("" for none)
 * @return {string} the RouterOS id of the new route
 * @throws {Error} kind "routeros" on a bad gateway
 */
export func addDefaultRoute(c as Client, gateway as string, comment as string) {
    return routeAdd($c, DEFAULT_ROUTE, $gateway, 0, $comment);
}

/**
 * Remove the static route to a destination.
 *
 * Only hand-made (non-dynamic) routes are considered. With several
 * static routes to the same destination (e.g. a backup with a higher
 * distance), the first one listed is removed - use the generic verbs
 * with the ids from `routes` for finer control.
 *
 * @param {Client} c          an open client
 * @param {string} dstAddress the destination network, exactly as listed
 * @throws {Error} kind "routeros" when no static route to it exists
 */
export func removeRoute(c as Client, dstAddress as string) {
    remove($c, ROUTE_PATH, requiredStaticRouteId($c, $dstAddress));
}

/**
 * Switch the static route to a destination on.
 *
 * @param {Client} c          an open client
 * @param {string} dstAddress the destination network, exactly as listed
 * @throws {Error} kind "routeros" when no static route to it exists
 */
export func enableRoute(c as Client, dstAddress as string) {
    enable($c, ROUTE_PATH, requiredStaticRouteId($c, $dstAddress));
}

/**
 * Switch the static route to a destination off.
 *
 * The route is kept but stops being used until enabled again.
 *
 * @param {Client} c          an open client
 * @param {string} dstAddress the destination network, exactly as listed
 * @throws {Error} kind "routeros" when no static route to it exists
 */
export func disableRoute(c as Client, dstAddress as string) {
    disable($c, ROUTE_PATH, requiredStaticRouteId($c, $dstAddress));
}

/**
 * Validate a route distance.
 *
 * @param {int} distance the candidate distance
 * @throws {Error} kind "routeros" when outside 1-255
 * @internal
 */
func ensureDistance(distance as int) {
    if ($distance < 1 or $distance > 255) {
        raiseError("the route distance must be between 1 and 255");
    }
}

/**
 * Validate and create a route; distance 0 means "router default".
 *
 * A gateway that is not an IP address must be an existing interface
 * (checked against the router), so a typo in either form is caught with
 * a clear message.
 *
 * @param {Client} c          an open client
 * @param {string} dstAddress destination network as CIDR
 * @param {string} gateway    next hop: IP address or interface name
 * @param {int}    distance   validated distance, or 0 to omit
 * @param {string} comment    friendly note ("" for none)
 * @return {string} the RouterOS id of the new route
 * @throws {Error} kind "routeros" on a malformed destination or gateway
 * @internal
 */
func routeAdd(c as Client, dstAddress as string, gateway as string, distance as int, comment as string) {
    ensureCidr($dstAddress);
    def gw as string init strings.trim($gateway);
    if ($gw == "") {
        raiseError("the gateway must not be empty");
    }
    if (not isIpAddress($gw)) {
        requiredId($c, INTERFACE_PATH, $gw, "gateway interface");
    }
    def attrs as map of string to string init {"dst-address": $dstAddress, "gateway": $gw};
    if ($distance > 0) {
        $attrs["distance"] = convert.toString($distance);
    }
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, ROUTE_PATH, $attrs);
}

/**
 * Find the first static (non-dynamic) route row to a destination.
 *
 * @param {list of map of string to string} rows "/ip/route/print" rows
 * @param {string} dstAddress the destination network to look for
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func staticRouteRow(rows as list of map of string to string, dstAddress as string) {
    for (def row in $rows) {
        if (rowValue($row, "dst-address") == $dstAddress and not rowBool($row, "dynamic")) {
            return $row;
        }
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Resolve a destination to the id of its static route, with a friendly
 * error when there is none.
 *
 * @param {Client} c          an open client
 * @param {string} dstAddress the destination network
 * @return {string} the route id
 * @throws {Error} kind "routeros" when no static route matches
 * @internal
 */
func requiredStaticRouteId(c as Client, dstAddress as string) {
    def rows as list of map of string to string init getAll($c, ROUTE_PATH);
    def row as map of string to string init staticRouteRow($rows, $dstAddress);
    if (len($row) == 0) {
        raiseError("no static route to \"" + $dstAddress + "\" was found");
    }
    return rowValue($row, ".id");
}

/**
 * Fold a reply row into a Route.
 *
 * @param {map of string to string} row an "/ip/route/print" row
 * @return {Route} the typed route
 * @internal
 */
func routeFromRow(row as map of string to string) {
    return Route{
        id: rowValue($row, ".id"),
        dstAddress: rowValue($row, "dst-address"),
        gateway: rowValue($row, "gateway"),
        distance: rowValue($row, "distance"),
        routingTable: rowValue($row, "routing-table"),
        active: rowBool($row, "active"),
        dynamic: rowBool($row, "dynamic"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * List the policy routing rules.
 *
 * @param {Client} c an open client
 * @return {list of RoutingRule} all rules, in evaluation order
 */
export func routingRules(c as Client) {
    def rows as list of map of string to string init getAll($c, ROUTING_RULE_PATH);
    def out as list of RoutingRule init [];
    for (def row in $rows) {
        $out[] = routingRuleFromRow($row);
    }
    return $out;
}

/**
 * Send a source's traffic through another routing table, with fallback.
 *
 * The clean way to do "this subnet uses the backup uplink": a rule
 * (matched before the main table) sends traffic from `srcAddress` to
 * table `table` - no per-packet marking needed (the mangle topic's
 * `markRoutingFor` is for matches that need firewall power). The table
 * is created if missing; give it a default route via the generic `add`
 * on ROUTE_PATH with `"routing-table": table`. With action "lookup",
 * destinations the table cannot answer fall back to the main table -
 * use `useRoutingTableOnly` for strict isolation. Idempotent.
 *
 * @param {Client} c          an open client
 * @param {string} srcAddress whose traffic: an IP or CIDR network
 * @param {string} table      the routing table to consult
 * @param {string} comment    friendly note ("" for none)
 * @return {string} the RouterOS id of the (new or existing) rule
 * @throws {Error} kind "routeros" on a bad address or table name
 * @example
 *   mt.useRoutingTable($c, "10.30.0.0/24", "backupisp", "guests via backup");
 *   mt.add($c, mt.ROUTE_PATH, {"dst-address": "0.0.0.0/0",
 *       "gateway": "198.51.100.1", "routing-table": "backupisp"});
 */
export func useRoutingTable(c as Client, srcAddress as string, table as string, comment as string) {
    return routingRuleAdd($c, $srcAddress, $table, "lookup", $comment);
}

/**
 * Send a source's traffic through another table, WITHOUT fallback.
 *
 * Strict isolation: destinations the table has no route for become
 * unreachable for the source - "backup uplink or nothing".
 *
 * @param {Client} c          an open client
 * @param {string} srcAddress whose traffic: an IP or CIDR network
 * @param {string} table      the routing table to consult
 * @param {string} comment    friendly note ("" for none)
 * @return {string} the RouterOS id of the (new or existing) rule
 * @throws {Error} kind "routeros" on a bad address or table name
 */
export func useRoutingTableOnly(c as Client, srcAddress as string, table as string, comment as string) {
    return routingRuleAdd($c, $srcAddress, $table, "lookup-only-in-table", $comment);
}

/**
 * Remove the policy routing rule sending a source to a table.
 *
 * @param {Client} c          an open client
 * @param {string} srcAddress the rule's source
 * @param {string} table      the rule's table
 * @throws {Error} kind "routeros" when no such rule exists
 */
export func removeRoutingRule(c as Client, srcAddress as string, table as string) {
    def rows as list of map of string to string init getAll($c, ROUTING_RULE_PATH);
    def row as map of string to string init
        findRoutingRuleRow($rows, strings.trim($srcAddress), $table);
    if (len($row) == 0) {
        raiseError("no routing rule sends \"" + $srcAddress + "\" to table \"" + $table + "\"");
    }
    remove($c, ROUTING_RULE_PATH, rowValue($row, ".id"));
}

/**
 * Validate and create (or reuse) a policy routing rule.
 *
 * @param {Client} c          an open client
 * @param {string} srcAddress the source (IP or CIDR)
 * @param {string} table      the routing table (created if missing)
 * @param {string} action     "lookup" or "lookup-only-in-table"
 * @param {string} comment    note, "" for none
 * @return {string} the RouterOS id of the rule
 * @throws {Error} kind "routeros" on a bad address or table name
 * @internal
 */
func routingRuleAdd(c as Client, srcAddress as string, table as string, action as string, comment as string) {
    def src as string init strings.trim($srcAddress);
    if (strings.contains($src, "/")) {
        ensureCidr($src);
    } else {
        ensureIpAddress($src);
    }
    ensureName($table, "routing table");
    ensureRoutingTable($c, $table);
    def rows as list of map of string to string init getAll($c, ROUTING_RULE_PATH);
    def existing as map of string to string init findRoutingRuleRow($rows, $src, $table);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    def attrs as map of string to string init
        {"src-address": $src, "action": $action, "table": $table};
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, ROUTING_RULE_PATH, $attrs);
}

/**
 * Create a routing table if it does not exist ("main" always does).
 *
 * @param {Client} c     an open client
 * @param {string} table the table name
 * @internal
 */
func ensureRoutingTable(c as Client, table as string) {
    if ($table == "main") {
        return;
    }
    if (idByName($c, ROUTING_TABLE_PATH, $table) == "") {
        add($c, ROUTING_TABLE_PATH, {"name": $table, "fib": ""});
    }
}

/**
 * Find the rule matching a source and a table.
 *
 * @param {list of map of string to string} rows "/routing/rule/print" rows
 * @param {string} src   the source address/network
 * @param {string} table the table name
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func findRoutingRuleRow(rows as list of map of string to string, src as string, table as string) {
    for (def row in $rows) {
        if (rowValue($row, "src-address") == $src and rowValue($row, "table") == $table) {
            return $row;
        }
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Fold a reply row into a RoutingRule.
 *
 * @param {map of string to string} row a "/routing/rule/print" row
 * @return {RoutingRule} the typed rule
 * @internal
 */
func routingRuleFromRow(row as map of string to string) {
    return RoutingRule{
        id: rowValue($row, ".id"),
        srcAddress: rowValue($row, "src-address"),
        dstAddress: rowValue($row, "dst-address"),
        interfaceName: rowValue($row, "interface"),
        action: rowValue($row, "action"),
        table: rowValue($row, "table"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
