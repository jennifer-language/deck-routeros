# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - firewall NAT: masquerade and port forwarding.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the firewall NAT-rule list. */
export def const NAT_PATH as string init "/ip/firewall/nat";

/** NAT chain for rewriting the source of outgoing traffic. */
export def const CHAIN_SRCNAT as string init "srcnat";

/** NAT chain for rewriting the destination of incoming traffic. */
export def const CHAIN_DSTNAT as string init "dstnat";

/** NAT action that hides a LAN behind the router's own address. */
export def const ACTION_MASQUERADE as string init "masquerade";

/** NAT action that redirects traffic to another address/port. */
export def const ACTION_DST_NAT as string init "dst-nat";

/**
 * One firewall NAT rule, as read back from the router.
 *
 * Create the two everyday kinds with `addMasquerade` (share the
 * router's address) and `forwardPort` (publish an inside service);
 * anything more exotic goes through the generic `add` on NAT_PATH.
 *
 * @field {string} id           internal RouterOS id
 * @field {string} chain        "srcnat" (outgoing) or "dstnat" (incoming)
 * @field {string} action       "masquerade", "dst-nat", ...
 * @field {string} protocol     matched IP protocol, "" for any
 * @field {string} srcAddress   matched source address/network, "" for any
 * @field {string} dstAddress   matched destination address/network, "" for any
 * @field {string} dstPort      matched destination port(s), "" for any
 * @field {string} toAddresses  where dst-nat sends the traffic
 * @field {string} toPorts      which port dst-nat sends it to
 * @field {string} inInterface  interface the packet arrives on, "" for any
 * @field {string} outInterface interface the packet leaves on, "" for any
 * @field {string} comment      free-text comment; the handle for the *ByComment helpers
 * @field {bool}   disabled     true when the rule is switched off
 */
export def struct NatRule {
    id as string,
    chain as string,
    action as string,
    protocol as string,
    srcAddress as string,
    dstAddress as string,
    dstPort as string,
    toAddresses as string,
    toPorts as string,
    inInterface as string,
    outInterface as string,
    comment as string,
    disabled as bool
};

/**
 * List every firewall NAT rule on the router.
 *
 * @param {Client} c an open client
 * @return {list of NatRule} all NAT rules, ids populated
 */
export func natRules(c as Client) {
    def rows as list of map of string to string init getAll($c, NAT_PATH);
    def out as list of NatRule init [];
    for (def row in $rows) {
        $out[] = natFromRow($row);
    }
    return $out;
}

/**
 * Let the LAN reach the internet through the router's address
 * (masquerade - the NAT rule every home/office router needs).
 *
 * All traffic leaving through `outInterface` (the WAN side) gets the
 * router's public address as its source. Idempotent: if a masquerade
 * rule for that interface already exists, its id is returned instead of
 * creating a duplicate.
 *
 * @param {Client} c            an open client
 * @param {string} outInterface the internet-facing interface (e.g. "ether1")
 * @param {string} comment      friendly note for a newly created rule ("" for none)
 * @return {string} the RouterOS id of the (new or existing) rule
 * @throws {Error} kind "routeros" when the interface does not exist
 * @example
 *   mt.addMasquerade($c, "ether1", "lan to internet");
 */
export func addMasquerade(c as Client, outInterface as string, comment as string) {
    requiredId($c, INTERFACE_PATH, $outInterface, "interface");
    def rows as list of map of string to string init getAll($c, NAT_PATH);
    def existing as map of string to string init findMasqueradeRow($rows, $outInterface);
    if (len($existing) > 0) {
        return rowValue($existing, ".id");
    }
    def attrs as map of string to string init {
        "chain": CHAIN_SRCNAT,
        "action": ACTION_MASQUERADE,
        "out-interface": $outInterface
    };
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, NAT_PATH, $attrs);
}

/**
 * Publish an inside service to the world (port forwarding).
 *
 * Traffic arriving at the router on `publicPort` is redirected to
 * `toAddress`:`toPort` on the LAN. Applies to any incoming interface -
 * prefer `forwardPortOn` to pin it to the WAN interface. Remember the
 * forward only works if the firewall also lets the traffic through the
 * forward chain.
 *
 * @param {Client} c          an open client
 * @param {string} protocol   "tcp" or "udp" (port forwarding needs one of the two)
 * @param {int}    publicPort port the outside world connects to (1-65535)
 * @param {string} toAddress  LAN address of the real service
 * @param {int}    toPort     port the service listens on (1-65535)
 * @param {string} comment    friendly handle for the rule (e.g. "web server")
 * @return {string} the RouterOS id of the new rule
 * @throws {Error} kind "routeros" on a bad protocol, port, or address
 * @example
 *   mt.forwardPort($c, "tcp", 8080, "192.168.88.10", 80, "web server");
 */
export func forwardPort(c as Client, protocol as string, publicPort as int, toAddress as string, toPort as int, comment as string) {
    return natForward($c, "", $protocol, $publicPort, $toAddress, $toPort, $comment);
}

/**
 * Like `forwardPort`, but only for traffic arriving on one interface.
 *
 * Pinning the rule to the WAN interface keeps the redirect from also
 * hijacking LAN-internal connections to the router.
 *
 * @param {Client} c           an open client
 * @param {string} inInterface the internet-facing interface (e.g. "ether1")
 * @param {string} protocol    "tcp" or "udp"
 * @param {int}    publicPort  port the outside world connects to (1-65535)
 * @param {string} toAddress   LAN address of the real service
 * @param {int}    toPort      port the service listens on (1-65535)
 * @param {string} comment     friendly handle for the rule
 * @return {string} the RouterOS id of the new rule
 * @throws {Error} kind "routeros" on bad input or an unknown interface
 */
export func forwardPortOn(c as Client, inInterface as string, protocol as string, publicPort as int, toAddress as string, toPort as int, comment as string) {
    requiredId($c, INTERFACE_PATH, $inInterface, "interface");
    return natForward($c, $inInterface, $protocol, $publicPort, $toAddress, $toPort, $comment);
}

/**
 * Delete a NAT rule by its RouterOS id.
 *
 * @param {Client} c  an open client
 * @param {string} id the rule id (as returned by the add calls or `natRules`)
 */
export func removeNatRule(c as Client, id as string) {
    remove($c, NAT_PATH, $id);
}

/**
 * Delete the NAT rule that carries a comment.
 *
 * @param {Client} c       an open client
 * @param {string} comment the comment given to the rule when it was created
 * @throws {Error} kind "routeros" when no NAT rule carries that comment
 */
export func removeNatRuleByComment(c as Client, comment as string) {
    remove($c, NAT_PATH, natIdByComment($c, $comment));
}

/**
 * Switch the NAT rule that carries a comment on.
 *
 * @param {Client} c       an open client
 * @param {string} comment the rule's comment
 * @throws {Error} kind "routeros" when no NAT rule carries that comment
 */
export func enableNatRuleByComment(c as Client, comment as string) {
    enable($c, NAT_PATH, natIdByComment($c, $comment));
}

/**
 * Switch the NAT rule that carries a comment off.
 *
 * Handy for temporarily closing a port forward without losing it.
 *
 * @param {Client} c       an open client
 * @param {string} comment the rule's comment
 * @throws {Error} kind "routeros" when no NAT rule carries that comment
 */
export func disableNatRuleByComment(c as Client, comment as string) {
    disable($c, NAT_PATH, natIdByComment($c, $comment));
}

/**
 * Validate a port-forward protocol: dst-nat needs tcp or udp.
 *
 * @param {string} protocol the candidate
 * @throws {Error} kind "routeros" on anything but "tcp" / "udp"
 * @internal
 */
func ensureForwardProtocol(protocol as string) {
    if ($protocol != "tcp" and $protocol != "udp") {
        raiseError("port forwarding needs protocol \"tcp\" or \"udp\", not \"" + $protocol + "\"");
    }
}

/**
 * Find an existing masquerade rule for an outgoing interface.
 *
 * @param {list of map of string to string} rows "/ip/firewall/nat/print" rows
 * @param {string} outInterface the interface to look for
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func findMasqueradeRow(rows as list of map of string to string, outInterface as string) {
    for (def row in $rows) {
        if (rowValue($row, "chain") == CHAIN_SRCNAT
                and rowValue($row, "action") == ACTION_MASQUERADE
                and rowValue($row, "out-interface") == $outInterface) {
            return $row;
        }
    }
    def none as map of string to string init {};
    return $none;
}

/**
 * Validate and create a dst-nat port forward; empty inInterface omits
 * the interface match.
 *
 * @param {Client} c           an open client
 * @param {string} inInterface interface match, "" for any
 * @param {string} protocol    "tcp" or "udp"
 * @param {int}    publicPort  outside port
 * @param {string} toAddress   inside address
 * @param {int}    toPort      inside port
 * @param {string} comment     friendly handle, "" for none
 * @return {string} the RouterOS id of the new rule
 * @throws {Error} kind "routeros" on bad input
 * @internal
 */
func natForward(c as Client, inInterface as string, protocol as string, publicPort as int, toAddress as string, toPort as int, comment as string) {
    ensureForwardProtocol($protocol);
    ensurePort($publicPort);
    ensurePort($toPort);
    ensureIpAddress($toAddress);
    def attrs as map of string to string init {
        "chain": CHAIN_DSTNAT,
        "action": ACTION_DST_NAT,
        "protocol": $protocol,
        "dst-port": convert.toString($publicPort),
        "to-addresses": strings.trim($toAddress),
        "to-ports": convert.toString($toPort)
    };
    if ($inInterface != "") {
        $attrs["in-interface"] = $inInterface;
    }
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, NAT_PATH, $attrs);
}

/**
 * Resolve a NAT rule comment to the rule's id.
 *
 * @param {Client} c       an open client
 * @param {string} comment the rule's comment
 * @return {string} the rule id
 * @throws {Error} kind "routeros" when no NAT rule carries that comment
 * @internal
 */
func natIdByComment(c as Client, comment as string) {
    def rows as list of map of string to string init getAll($c, NAT_PATH);
    def row as map of string to string init findRowByField($rows, "comment", $comment);
    if (len($row) == 0) {
        raiseError("no NAT rule with the comment \"" + $comment + "\" was found");
    }
    return rowValue($row, ".id");
}

/**
 * Fold a reply row into a NatRule.
 *
 * @param {map of string to string} row an "/ip/firewall/nat/print" row
 * @return {NatRule} the typed rule
 * @internal
 */
func natFromRow(row as map of string to string) {
    return NatRule{
        id: rowValue($row, ".id"),
        chain: rowValue($row, "chain"),
        action: rowValue($row, "action"),
        protocol: rowValue($row, "protocol"),
        srcAddress: rowValue($row, "src-address"),
        dstAddress: rowValue($row, "dst-address"),
        dstPort: rowValue($row, "dst-port"),
        toAddresses: rowValue($row, "to-addresses"),
        toPorts: rowValue($row, "to-ports"),
        inInterface: rowValue($row, "in-interface"),
        outInterface: rowValue($row, "out-interface"),
        comment: rowValue($row, "comment"),
        disabled: rowBool($row, "disabled")
    };
}
