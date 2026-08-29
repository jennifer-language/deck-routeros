# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - mangle: marking traffic for queues and policy routing.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the firewall mangle-rule list. */
export def const MANGLE_PATH as string init "/ip/firewall/mangle";

/** Mangle chain for traffic as it enters, before routing decisions. */
export def const CHAIN_PREROUTING as string init "prerouting";

/** Mangle chain for traffic as it leaves, after routing decisions. */
export def const CHAIN_POSTROUTING as string init "postrouting";

/**
 * One mangle rule, as read back from the router.
 *
 * Create the everyday shapes with `setupPacketMark`, `markRoutingFor`,
 * and `clampTcpMss`; anything more exotic goes through the generic
 * `add` on MANGLE_PATH.
 *
 * @field {string} id                internal RouterOS id
 * @field {string} chain             "prerouting", "forward", "postrouting", ...
 * @field {string} action            "mark-connection", "mark-packet",
 *                                   "mark-routing", "change-mss", ...
 * @field {string} newConnectionMark mark stamped on connections, "" when none
 * @field {string} newPacketMark     mark stamped on packets, "" when none
 * @field {string} newRoutingMark    routing table sent to, "" when none
 * @field {string} newMss            MSS value set by change-mss, "" when none
 * @field {string} connectionMark    matched connection mark, "" for any
 * @field {string} packetMark        matched packet mark, "" for any
 * @field {string} protocol          matched protocol, "" for any
 * @field {string} srcAddress        matched source, "" for any
 * @field {string} dstAddress        matched destination, "" for any
 * @field {string} dstPort           matched destination port(s), "" for any
 * @field {string} inInterface       matched incoming interface, "" for any
 * @field {string} outInterface      matched outgoing interface, "" for any
 * @field {bool}   passthrough       true when later rules still see the packet
 * @field {bool}   disabled          true when the rule is switched off
 * @field {string} comment           free-text comment; the handle the setup
 *                                   helpers use
 */
export def struct MangleRule {
    id as string,
    chain as string,
    action as string,
    newConnectionMark as string,
    newPacketMark as string,
    newRoutingMark as string,
    newMss as string,
    connectionMark as string,
    packetMark as string,
    protocol as string,
    srcAddress as string,
    dstAddress as string,
    dstPort as string,
    inInterface as string,
    outInterface as string,
    passthrough as bool,
    disabled as bool,
    comment as string
};

/**
 * List every mangle rule on the router.
 *
 * @param {Client} c an open client
 * @return {list of MangleRule} all mangle rules
 */
export func mangleRules(c as Client) {
    def rows as list of map of string to string init getAll($c, MANGLE_PATH);
    def out as list of MangleRule init [];
    for (def row in $rows) {
        $out[] = mangleFromRow($row);
    }
    return $out;
}

/**
 * Mark a kind of traffic so queues can treat it specially.
 *
 * Creates RouterOS's canonical two-step in one call: new connections
 * matching the matcher get a connection mark, and every packet of a
 * marked connection gets packet mark `markName`. Queues then match the
 * packet mark (a simple queue's `packet-marks` property, via the
 * generic `set`) instead of addresses. Build the matcher with the
 * firewall builder - its chain is used (CHAIN_PREROUTING is right for
 * queue marks), its action is replaced by the marking actions.
 * Idempotent by mark name.
 *
 * @param {Client}       c        an open client
 * @param {string}       markName the packet mark to create (e.g. "voip")
 * @param {FirewallRule} matcher  what to mark, built with `firewallRule`
 *                                and the `with*` refiners
 * @return {string} the RouterOS id of the packet-marking rule
 * @throws {Error} kind "routeros" on a bad mark name or matcher
 * @example
 *   def m as mt.FirewallRule init mt.firewallRule(mt.CHAIN_PREROUTING, mt.ACTION_ACCEPT);
 *   $m = mt.withProtocol($m, "udp");
 *   $m = mt.withDstPort($m, "5060-5200");
 *   mt.setupPacketMark($c, "voip", $m);
 */
export func setupPacketMark(c as Client, markName as string, matcher as FirewallRule) {
    ensureName($markName, "packet mark");
    def pair as list of map of string to string init packetMarkRuleAttrs($matcher, $markName);
    def rows as list of map of string to string init getAll($c, MANGLE_PATH);
    def existing as map of string to string init findRowByField(
        $rows,
        "comment",
        "mark: " + $markName + " (packets)");
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    add($c, MANGLE_PATH, $pair[0]);
    return add($c, MANGLE_PATH, $pair[1]);
}

/**
 * Remove a packet mark's rule pair.
 *
 * Queues still matching the mark simply stop seeing marked packets.
 *
 * @param {Client} c        an open client
 * @param {string} markName the mark given to `setupPacketMark`
 * @throws {Error} kind "routeros" when no such mark pair exists
 */
export func removePacketMark(c as Client, markName as string) {
    def rows as list of map of string to string init getAll($c, MANGLE_PATH);
    def found as int init 0;
    for (def row in $rows) {
        def comment as string init rowValue($row, "comment");
        if ($comment == "mark: " + $markName + " (connections)" or $comment == "mark: " +
            $markName + " (packets)") {
            remove($c, MANGLE_PATH, rowValue($row, ".id"));
            $found = $found + 1;
        }
    }
    if ($found == 0) {
        raiseError("no packet mark \"" + $markName +
            "\" was found - was it created with setupPacketMark?");
    }
}

/**
 * Send a source's traffic to a different routing table (policy routing).
 *
 * The "this subnet uses the backup uplink" tool: traffic from
 * `srcAddress` gets routing mark `markName` and is looked up in the
 * routing table of that name instead of `main`. On RouterOS v7 the
 * table must exist first (`/routing/table add name=<mark> fib` -
 * generic verbs) and needs its own default route (generic `add` on
 * ROUTE_PATH with `"routing-table": markName`). Idempotent by mark
 * and source.
 *
 * @param {Client} c          an open client
 * @param {string} markName   the routing mark / table name
 * @param {string} srcAddress whose traffic: an IP or CIDR network
 * @return {string} the RouterOS id of the marking rule
 * @throws {Error} kind "routeros" on a bad mark name or address
 */
export func markRoutingFor(c as Client, markName as string, srcAddress as string) {
    ensureName($markName, "routing mark");
    def src as string init strings.trim($srcAddress);
    if (strings.contains($src, "/")) {
        ensureCidr($src);
    } else {
        ensureIpAddress($src);
    }
    def rows as list of map of string to string init getAll($c, MANGLE_PATH);
    def comment as string init "route mark: " + $markName + " for " + $src;
    def existing as map of string to string init findRowByField($rows, "comment", $comment);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    return add($c, MANGLE_PATH, routingMarkAttrs($markName, $src));
}

/**
 * Remove the routing mark for a source.
 *
 * @param {Client} c          an open client
 * @param {string} markName   the routing mark
 * @param {string} srcAddress the source it was created for
 * @throws {Error} kind "routeros" when no such marking rule exists
 */
export func removeRoutingMark(c as Client, markName as string, srcAddress as string) {
    def rows as list of map of string to string init getAll($c, MANGLE_PATH);
    def comment as string init "route mark: " + $markName + " for " + strings.trim($srcAddress);
    def row as map of string to string init findRowByField($rows, "comment", $comment);
    if (len($row) == 0) {
        raiseError("no routing mark \"" + $markName + "\" for \"" + $srcAddress + "\" was found");
    }
    remove($c, MANGLE_PATH, rowValue($row, ".id"));
}

/**
 * Clamp TCP MSS on an interface, both directions.
 *
 * The fix for "ping works, pages half-load" over PPPoE and tunnels:
 * TCP handshakes crossing the interface get their maximum segment size
 * clamped to what the path actually fits. Creates one rule per
 * direction; idempotent.
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the small-MTU interface (e.g. "pppoewan",
 *                               a GRE or EoIP tunnel)
 * @throws {Error} kind "routeros" when the interface does not exist
 * @example
 *   mt.clampTcpMss($c, "pppoewan");
 */
export func clampTcpMss(c as Client, interfaceName as string) {
    requiredId($c, INTERFACE_PATH, $interfaceName, "interface");
    def rows as list of map of string to string init getAll($c, MANGLE_PATH);
    def directions as list of string init ["out", "in"];
    for (def direction in $directions) {
        def attrs as map of string to string init mssClampAttrs($interfaceName, $direction);
        def existing as map of string to string init findRowByField(
            $rows,
            "comment",
            $attrs["comment"]);
        if (len($existing) == 0) {
            add($c, MANGLE_PATH, $attrs);
        }
    }
}

/**
 * Remove the MSS clamp from an interface (both directions).
 *
 * @param {Client} c             an open client
 * @param {string} interfaceName the interface it was clamped on
 * @throws {Error} kind "routeros" when no clamp rules exist there
 */
export func removeTcpMssClamp(c as Client, interfaceName as string) {
    def rows as list of map of string to string init getAll($c, MANGLE_PATH);
    def found as int init 0;
    for (def row in $rows) {
        def comment as string init rowValue($row, "comment");
        if ($comment == "mss clamp: " + $interfaceName + " (out)" or $comment == "mss clamp: " +
            $interfaceName + " (in)") {
            remove($c, MANGLE_PATH, rowValue($row, ".id"));
            $found = $found + 1;
        }
    }
    if ($found == 0) {
        raiseError("no MSS clamp on \"" + $interfaceName + "\" was found");
    }
}

/**
 * Build the canonical mark-connection / mark-packet attribute pair
 * from a matcher rule.
 *
 * The matcher's chain is kept; its action is replaced. The connection
 * rule marks only new connections (efficient) and passes through; the
 * packet rule matches the connection mark and stops.
 *
 * @param {FirewallRule} matcher  the match, built with the firewall builder
 * @param {string}       markName the packet mark
 * @return {list of map of string to string} two attribute maps:
 *         the connection rule, then the packet rule
 * @internal
 */
func packetMarkRuleAttrs(matcher as FirewallRule, markName as string) {
    def connName as string init $markName + "-conn";
    def connAttrs as map of string to string init ruleAttrs($matcher);
    $connAttrs["action"] = "mark-connection";
    $connAttrs["new-connection-mark"] = $connName;
    $connAttrs["connection-state"] = "new";
    $connAttrs["passthrough"] = "yes";
    $connAttrs["comment"] = "mark: " + $markName + " (connections)";
    def pktAttrs as map of string to string init {
        "chain": $connAttrs["chain"],
        "action": "mark-packet",
        "connection-mark": $connName,
        "new-packet-mark": $markName,
        "passthrough": "no",
        "comment": "mark: " + $markName + " (packets)"
    };
    def out as list of map of string to string init [];
    $out[] = $connAttrs;
    $out[] = $pktAttrs;
    return $out;
}

/**
 * Build the mark-routing attributes for a source.
 *
 * @param {string} markName the routing mark / table
 * @param {string} src      the validated source (IP or CIDR)
 * @return {map of string to string} the rule attributes
 * @internal
 */
func routingMarkAttrs(markName as string, src as string) {
    return {
        "chain": CHAIN_PREROUTING,
        "action": "mark-routing",
        "src-address": $src,
        "new-routing-mark": $markName,
        "passthrough": "yes",
        "comment": "route mark: " + $markName + " for " + $src
    };
}

/**
 * Build the change-mss attributes for one direction of an interface.
 *
 * @param {string} interfaceName the small-MTU interface
 * @param {string} direction     "out" or "in"
 * @return {map of string to string} the rule attributes
 * @internal
 */
func mssClampAttrs(interfaceName as string, direction as string) {
    def attrs as map of string to string init {
        "chain": "forward",
        "action": "change-mss",
        "protocol": "tcp",
        "tcp-flags": "syn",
        "new-mss": "clamp-to-pmtu",
        "passthrough": "yes",
        "comment": "mss clamp: " + $interfaceName + " (" + $direction + ")"
    };
    if ($direction == "out") {
        $attrs["out-interface"] = $interfaceName;
    } else {
        $attrs["in-interface"] = $interfaceName;
    }
    return $attrs;
}

/**
 * Fold a reply row into a MangleRule.
 *
 * @param {map of string to string} row an "/ip/firewall/mangle/print" row
 * @return {MangleRule} the typed rule
 * @internal
 */
func mangleFromRow(row as map of string to string) {
    return MangleRule{
        id: rowValue($row, ".id"),
        chain: rowValue($row, "chain"),
        action: rowValue($row, "action"),
        newConnectionMark: rowValue($row, "new-connection-mark"),
        newPacketMark: rowValue($row, "new-packet-mark"),
        newRoutingMark: rowValue($row, "new-routing-mark"),
        newMss: rowValue($row, "new-mss"),
        connectionMark: rowValue($row, "connection-mark"),
        packetMark: rowValue($row, "packet-mark"),
        protocol: rowValue($row, "protocol"),
        srcAddress: rowValue($row, "src-address"),
        dstAddress: rowValue($row, "dst-address"),
        dstPort: rowValue($row, "dst-port"),
        inInterface: rowValue($row, "in-interface"),
        outInterface: rowValue($row, "out-interface"),
        passthrough: rowBool($row, "passthrough"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * Move a mangle rule so it is evaluated directly before another one.
 *
 * Mangle order decides which mark sticks: the first matching rule marks
 * the packet, and a later rule that would have marked it differently
 * never runs unless the earlier one passes traffic through.
 *
 * @param {Client} c        an open client
 * @param {string} id       the rule to move
 * @param {string} beforeId the rule it must end up above, "" for the bottom
 * @throws {Error} kind "routeros" on an empty id or a self-move
 */
export func moveMangleRule(c as Client, id as string, beforeId as string) {
    moveRule($c, MANGLE_PATH, $id, $beforeId);
}

/**
 * Move the mangle rule carrying one comment above the rule carrying another.
 *
 * @param {Client} c             an open client
 * @param {string} comment       the rule to move
 * @param {string} beforeComment the rule it must end up above, "" for the bottom
 * @throws {Error} kind "routeros" when either comment matches no rule
 */
export func moveMangleRuleByComment(c as Client, comment as string, beforeComment as string) {
    def target as string init mangleIdByComment($c, $comment);
    def dest as string init "";
    if (strings.trim($beforeComment) != "") {
        $dest = mangleIdByComment($c, $beforeComment);
    }
    moveRule($c, MANGLE_PATH, $target, $dest);
}

/**
 * Resolve a mangle rule comment to the rule's id.
 *
 * @param {Client} c       an open client
 * @param {string} comment the rule's comment
 * @return {string} the rule id
 * @throws {Error} kind "routeros" when no mangle rule carries that comment
 * @internal
 */
func mangleIdByComment(c as Client, comment as string) {
    return requiredIdByComment($c, MANGLE_PATH, $comment, "mangle rule");
}
