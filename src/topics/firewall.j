# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - firewall filter rules.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the firewall filter-rule list. */
export def const FIREWALL_PATH as string init "/ip/firewall/filter";

/** Firewall chain for traffic addressed to the router itself. */
export def const CHAIN_INPUT as string init "input";

/** Firewall chain for traffic routed through the router. */
export def const CHAIN_FORWARD as string init "forward";

/** Firewall chain for traffic originating from the router. */
export def const CHAIN_OUTPUT as string init "output";

/** Firewall action that lets a packet pass. */
export def const ACTION_ACCEPT as string init "accept";

/** Firewall action that silently discards a packet. */
export def const ACTION_DROP as string init "drop";

/** Firewall action that discards a packet and tells the sender. */
export def const ACTION_REJECT as string init "reject";

/** Raw-table action that exempts a packet from connection tracking. */
export def const ACTION_NOTRACK as string init "notrack";

def const KNOWN_ACTIONS as list of string init [
    "accept",
    "drop",
    "reject",
    "log",
    "jump",
    "return",
    "passthrough",
    "tarpit",
    "fasttrack-connection",
    "notrack"
];

def const KNOWN_PROTOCOLS as list of string init [
    "tcp",
    "udp",
    "icmp",
    "gre",
    "ipip",
    "ospf",
    "igmp",
    "ipsec-esp",
    "ipsec-ah",
    "l2tp",
    "sctp",
    "vrrp"
];

/**
 * One firewall filter rule, both as a builder and as a query result.
 *
 * Build one with `firewallRule` and refine it with the value-semantic
 * `with*` helpers; unset string fields stay "" and are simply omitted
 * from the router command. Rules read back with `firewallRules` carry
 * their `id`.
 *
 * @field {string} id           internal RouterOS id, "" on a rule you build
 * @field {string} chain        chain the rule lives in (input / forward / output)
 * @field {string} action       what to do on a match (accept / drop / reject / ...)
 * @field {string} protocol     IP protocol to match, "" for any
 * @field {string} srcAddress   source address or CIDR network, "" for any
 * @field {string} dstAddress   destination address or CIDR network, "" for any
 * @field {string} srcAddressList source address list (see ADDRESS_LIST_PATH), "" for none
 * @field {string} dstAddressList destination address list, "" for none
 * @field {string} srcPort      source port, list, or range, "" for any
 * @field {string} dstPort      destination port, list, or range, "" for any
 * @field {string} inInterface  interface the packet arrived on, "" for any
 * @field {string} outInterface interface the packet would leave on, "" for any
 * @field {string} comment      free-text comment; doubles as a friendly handle
 * @field {bool}   disabled     true when the rule is created switched off
 */
export def struct FirewallRule {
    id as string,
    chain as string,
    action as string,
    protocol as string,
    srcAddress as string,
    dstAddress as string,
    srcAddressList as string,
    dstAddressList as string,
    srcPort as string,
    dstPort as string,
    inInterface as string,
    outInterface as string,
    inInterfaceList as string,
    outInterfaceList as string,
    comment as string,
    disabled as bool
};

/**
 * Start a firewall filter rule.
 *
 * Returns a rule that matches every packet in `chain` and applies
 * `action`; narrow it down with the `with*` helpers, then create it on
 * the router with `addFirewallRule`.
 *
 * @param {string} chain  which traffic to look at - use CHAIN_INPUT
 *                        (to the router), CHAIN_FORWARD (through the
 *                        router), or CHAIN_OUTPUT (from the router)
 * @param {string} action what to do on a match - use ACTION_ACCEPT,
 *                        ACTION_DROP, or ACTION_REJECT
 * @return {FirewallRule} the rule under construction
 * @throws {Error} kind "routeros" on an empty chain or unknown action
 * @example
 *   def r as mt.FirewallRule init mt.firewallRule(mt.CHAIN_INPUT, mt.ACTION_ACCEPT);
 *   $r = mt.withProtocol($r, "tcp");
 *   $r = mt.withDstPort($r, "22,443");
 *   mt.addFirewallRule($c, $r);
 */
export func firewallRule(chain as string, action as string) {
    ensureName($chain, "chain");
    ensureAction($action);
    return FirewallRule{
        id: "",
        chain: $chain,
        action: $action,
        protocol: "",
        srcAddress: "",
        dstAddress: "",
        srcAddressList: "",
        dstAddressList: "",
        srcPort: "",
        dstPort: "",
        inInterface: "",
        outInterface: "",
        inInterfaceList: "",
        outInterfaceList: "",
        comment: "",
        disabled: false
    };
}

/**
 * Return a copy of a rule that matches sources from an address list.
 *
 * The list is managed under ADDRESS_LIST_PATH (`addToAddressList` and
 * friends); the rule follows the list as it changes.
 *
 * @param {FirewallRule} rule     the rule to refine
 * @param {string}       listName the address list name (e.g. "blocklist")
 * @return {FirewallRule} the refined copy
 * @throws {Error} kind "routeros" on an empty list name
 */
export func withSrcAddressList(rule as FirewallRule, listName as string) {
    ensureName($listName, "address list");
    $rule.srcAddressList = $listName;
    return $rule;
}

/**
 * Return a copy of a rule that matches destinations from an address list.
 *
 * @param {FirewallRule} rule     the rule to refine
 * @param {string}       listName the address list name
 * @return {FirewallRule} the refined copy
 * @throws {Error} kind "routeros" on an empty list name
 */
export func withDstAddressList(rule as FirewallRule, listName as string) {
    ensureName($listName, "address list");
    $rule.dstAddressList = $listName;
    return $rule;
}

/**
 * Return a copy of a rule that matches one IP protocol.
 *
 * @param {FirewallRule} rule     the rule to refine
 * @param {string}       protocol e.g. "tcp", "udp", "icmp"
 * @return {FirewallRule} the refined copy
 * @throws {Error} kind "routeros" on an unknown protocol
 */
export func withProtocol(rule as FirewallRule, protocol as string) {
    ensureProtocol($protocol);
    $rule.protocol = $protocol;
    return $rule;
}

/**
 * Return a copy of a rule that matches a source address or network.
 *
 * @param {FirewallRule} rule    the rule to refine
 * @param {string}       address e.g. "203.0.113.7" or "10.0.0.0/8"
 * @return {FirewallRule} the refined copy
 */
export func withSrcAddress(rule as FirewallRule, address as string) {
    ensureName($address, "address");
    $rule.srcAddress = $address;
    return $rule;
}

/**
 * Return a copy of a rule that matches a destination address or network.
 *
 * @param {FirewallRule} rule    the rule to refine
 * @param {string}       address e.g. "192.168.88.1" or "192.168.88.0/24"
 * @return {FirewallRule} the refined copy
 */
export func withDstAddress(rule as FirewallRule, address as string) {
    ensureName($address, "address");
    $rule.dstAddress = $address;
    return $rule;
}

/**
 * Return a copy of a rule that matches one or more source ports.
 *
 * Requires a protocol (tcp or udp) on the rule by the time it is added.
 *
 * @param {FirewallRule} rule the rule to refine
 * @param {string}       spec a port ("80"), list ("80,443"), or range ("8000-8100")
 * @return {FirewallRule} the refined copy
 * @throws {Error} kind "routeros" on characters outside digits, comma, dash
 */
export func withSrcPort(rule as FirewallRule, spec as string) {
    ensurePortSpec($spec);
    $rule.srcPort = $spec;
    return $rule;
}

/**
 * Return a copy of a rule that matches one or more destination ports.
 *
 * Requires a protocol (tcp or udp) on the rule by the time it is added.
 *
 * @param {FirewallRule} rule the rule to refine
 * @param {string}       spec a port ("80"), list ("80,443"), or range ("8000-8100")
 * @return {FirewallRule} the refined copy
 * @throws {Error} kind "routeros" on characters outside digits, comma, dash
 */
export func withDstPort(rule as FirewallRule, spec as string) {
    ensurePortSpec($spec);
    $rule.dstPort = $spec;
    return $rule;
}

/**
 * Return a copy of a rule that matches packets arriving on one interface.
 *
 * @param {FirewallRule} rule the rule to refine
 * @param {string}       name interface name (e.g. "ether1")
 * @return {FirewallRule} the refined copy
 */
export func withInInterface(rule as FirewallRule, name as string) {
    ensureName($name, "interface");
    $rule.inInterface = $name;
    return $rule;
}

/**
 * Return a copy of a rule that matches packets leaving on one interface.
 *
 * @param {FirewallRule} rule the rule to refine
 * @param {string}       name interface name (e.g. "ether1")
 * @return {FirewallRule} the refined copy
 */
export func withOutInterface(rule as FirewallRule, name as string) {
    ensureName($name, "interface");
    $rule.outInterface = $name;
    return $rule;
}

/**
 * Return a copy of a rule that matches packets arriving on any interface
 * in an interface list (see the interface-list topic - e.g. the "WAN"
 * or "LAN" group in a v7 default config).
 *
 * @param {FirewallRule} rule     the rule to refine
 * @param {string}       listName the interface list name
 * @return {FirewallRule} the refined copy
 * @throws {Error} kind "routeros" on an empty list name
 */
export func withInInterfaceList(rule as FirewallRule, listName as string) {
    ensureName($listName, "interface list");
    $rule.inInterfaceList = $listName;
    return $rule;
}

/**
 * Return a copy of a rule that matches packets leaving on any interface
 * in an interface list.
 *
 * @param {FirewallRule} rule     the rule to refine
 * @param {string}       listName the interface list name
 * @return {FirewallRule} the refined copy
 * @throws {Error} kind "routeros" on an empty list name
 */
export func withOutInterfaceList(rule as FirewallRule, listName as string) {
    ensureName($listName, "interface list");
    $rule.outInterfaceList = $listName;
    return $rule;
}

/**
 * Return a copy of a rule carrying a comment.
 *
 * The comment is also the friendly handle the *ByComment helpers use,
 * so give every rule a distinct one.
 *
 * @param {FirewallRule} rule    the rule to refine
 * @param {string}       comment free text describing the rule
 * @return {FirewallRule} the refined copy
 */
export func withComment(rule as FirewallRule, comment as string) {
    $rule.comment = $comment;
    return $rule;
}

/**
 * Return a copy of a rule with its disabled flag set.
 *
 * @param {FirewallRule} rule     the rule to refine
 * @param {bool}         disabled true to create the rule switched off
 * @return {FirewallRule} the refined copy
 */
export func withDisabled(rule as FirewallRule, disabled as bool) {
    $rule.disabled = $disabled;
    return $rule;
}

/**
 * List every firewall filter rule on the router.
 *
 * @param {Client} c an open client
 * @return {list of FirewallRule} all filter rules, ids populated
 */
export func firewallRules(c as Client) {
    def rows as list of map of string to string init getAll($c, FIREWALL_PATH);
    def out as list of FirewallRule init [];
    for (def row in $rows) {
        $out[] = firewallRuleFromRow($row);
    }
    return $out;
}

/**
 * Create a firewall filter rule on the router.
 *
 * @param {Client}       c    an open client
 * @param {FirewallRule} rule a rule built with `firewallRule` and the `with*` helpers
 * @return {string} the RouterOS id of the new rule
 * @throws {Error} kind "routeros" on an inconsistent rule (e.g. a port
 *                 match without a protocol), kind "mikrotik" when the router refuses
 */
export func addFirewallRule(c as Client, rule as FirewallRule) {
    return add($c, FIREWALL_PATH, ruleAttrs($rule));
}

/**
 * Delete a firewall rule by its RouterOS id.
 *
 * @param {Client} c  an open client
 * @param {string} id the rule id (as returned by `addFirewallRule` or `firewallRules`)
 */
export func removeFirewallRule(c as Client, id as string) {
    remove($c, FIREWALL_PATH, $id);
}

/**
 * Delete the firewall rule that carries a comment.
 *
 * @param {Client} c       an open client
 * @param {string} comment the comment given to the rule when it was created
 * @throws {Error} kind "routeros" when no rule carries that comment
 */
export func removeFirewallRuleByComment(c as Client, comment as string) {
    remove($c, FIREWALL_PATH, firewallIdByComment($c, $comment));
}

/**
 * Switch the firewall rule that carries a comment on.
 *
 * @param {Client} c       an open client
 * @param {string} comment the rule's comment
 * @throws {Error} kind "routeros" when no rule carries that comment
 */
export func enableFirewallRuleByComment(c as Client, comment as string) {
    enable($c, FIREWALL_PATH, firewallIdByComment($c, $comment));
}

/**
 * Switch the firewall rule that carries a comment off.
 *
 * The rule is kept but stops matching until enabled again.
 *
 * @param {Client} c       an open client
 * @param {string} comment the rule's comment
 * @throws {Error} kind "routeros" when no rule carries that comment
 */
export func disableFirewallRuleByComment(c as Client, comment as string) {
    disable($c, FIREWALL_PATH, firewallIdByComment($c, $comment));
}

/**
 * Move a firewall rule so it is evaluated directly before another one.
 *
 * The filter chains are walked top to bottom and stop at the first
 * match, so a rule added last sits below a broad drop and never fires.
 * This lifts it back above that drop.
 *
 * @param {Client} c        an open client
 * @param {string} id       the rule to move
 * @param {string} beforeId the rule it must end up above, "" for the bottom
 * @throws {Error} kind "routeros" on an empty id or a self-move
 * @example
 *   def wg as string init mt.allowService($c, "udp", 13231, "wireguard in");
 *   mt.moveFirewallRule($c, $wg, $dropEverythingElseId);
 */
export func moveFirewallRule(c as Client, id as string, beforeId as string) {
    moveRule($c, FIREWALL_PATH, $id, $beforeId);
}

/**
 * Move the firewall rule carrying one comment above the rule carrying
 * another - the same reorder, addressed by the handles you named the
 * rules with instead of by ids that change.
 *
 * @param {Client} c             an open client
 * @param {string} comment       the rule to move
 * @param {string} beforeComment the rule it must end up above, "" for the bottom
 * @throws {Error} kind "routeros" when either comment matches no rule
 * @example
 *   mt.moveFirewallRuleByComment($c, "wireguard in", "drop everything else");
 */
export func moveFirewallRuleByComment(c as Client, comment as string, beforeComment as string) {
    def target as string init firewallIdByComment($c, $comment);
    def dest as string init "";
    if (strings.trim($beforeComment) != "") {
        $dest = firewallIdByComment($c, $beforeComment);
    }
    moveRule($c, FIREWALL_PATH, $target, $dest);
}

/**
 * Open one TCP or UDP service to the router itself.
 *
 * Shorthand for an accept rule on the input chain.
 *
 * @param {Client} c        an open client
 * @param {string} protocol "tcp" or "udp"
 * @param {int}    port     the service port (1-65535)
 * @param {string} comment  friendly handle for the rule (e.g. "ssh management")
 * @return {string} the RouterOS id of the new rule
 * @throws {Error} kind "routeros" on a bad protocol or port
 */
export func allowService(c as Client, protocol as string, port as int, comment as string) {
    ensurePort($port);
    def r as FirewallRule init firewallRule(CHAIN_INPUT, ACTION_ACCEPT);
    $r = withProtocol($r, $protocol);
    $r = withDstPort($r, convert.toString($port));
    $r = withComment($r, $comment);
    return addFirewallRule($c, $r);
}

/**
 * Drop every packet a source address sends to the router.
 *
 * Shorthand for a drop rule on the input chain.
 *
 * @param {Client} c       an open client
 * @param {string} address source address or CIDR network to block
 * @param {string} comment friendly handle for the rule (e.g. "known scanner")
 * @return {string} the RouterOS id of the new rule
 * @throws {Error} kind "routeros" on an empty address
 */
export func blockAddress(c as Client, address as string, comment as string) {
    def r as FirewallRule init firewallRule(CHAIN_INPUT, ACTION_DROP);
    $r = withSrcAddress($r, $address);
    $r = withComment($r, $comment);
    return addFirewallRule($c, $r);
}

/**
 * Resolve a firewall rule comment to the rule's id.
 *
 * @param {Client} c       an open client
 * @param {string} comment the rule's comment
 * @return {string} the rule id
 * @throws {Error} kind "routeros" when no rule carries that comment
 * @internal
 */
func firewallIdByComment(c as Client, comment as string) {
    return requiredIdByComment($c, FIREWALL_PATH, $comment, "firewall rule");
}

/**
 * Validate a firewall action against the known RouterOS actions.
 *
 * @param {string} action the candidate action
 * @throws {Error} kind "routeros" on an unknown action
 * @internal
 */
func ensureAction(action as string) {
    if (not lists.contains(KNOWN_ACTIONS, $action)) {
        raiseError("unknown firewall action \"" + $action + "\" - use one of: " +
            strings.join(KNOWN_ACTIONS, ", "));
    }
}

/**
 * Validate an IP protocol against the known RouterOS protocols.
 *
 * @param {string} protocol the candidate protocol
 * @throws {Error} kind "routeros" on an unknown protocol
 * @internal
 */
func ensureProtocol(protocol as string) {
    if (not lists.contains(KNOWN_PROTOCOLS, $protocol)) {
        raiseError("unknown protocol \"" + $protocol + "\" - use one of: " +
            strings.join(KNOWN_PROTOCOLS, ", "));
    }
}

/**
 * Add an input-chain accept rule if one with the comment does not
 * already exist (idempotent). Shared by the VPN server helpers to open
 * their ports.
 *
 * @param {Client} c       an open client
 * @param {string} comment the rule's handle
 * @param {map of string to string} matchAttrs extra match attributes
 *        (protocol, dst-port, ...) merged onto chain=input action=accept
 * @internal
 */
func ensureInputAccept(c as Client, comment as string, matchAttrs as map of string to string) {
    def rows as list of map of string to string init getAll($c, FIREWALL_PATH);
    def existing as map of string to string init findRowByField($rows, "comment", $comment);
    if (len($existing) > 0) {
        return;
    }
    def attrs as map of string to string init {
        "chain": CHAIN_INPUT,
        "action": ACTION_ACCEPT,
        "comment": $comment
    };
    def keys as list of string init maps.keys($matchAttrs);
    for (def k in $keys) {
        $attrs[$k] = $matchAttrs[$k];
    }
    add($c, FIREWALL_PATH, $attrs);
}

/**
 * Remove every firewall rule whose comment starts with a prefix.
 *
 * @param {Client} c      an open client
 * @param {string} prefix the comment prefix to sweep
 * @return {int} how many rules were removed
 * @internal
 */
func removeInputAcceptsByPrefix(c as Client, prefix as string) {
    def rows as list of map of string to string init getAll($c, FIREWALL_PATH);
    def removed as int init 0;
    for (def row in $rows) {
        if (strings.startsWith(rowValue($row, "comment"), $prefix)) {
            remove($c, FIREWALL_PATH, rowValue($row, ".id"));
            $removed = $removed + 1;
        }
    }
    return $removed;
}

/**
 * Fold a reply row into a FirewallRule.
 *
 * @param {map of string to string} row a "/ip/firewall/filter/print" row
 * @return {FirewallRule} the typed rule
 * @internal
 */
func firewallRuleFromRow(row as map of string to string) {
    return FirewallRule{
        id: rowValue($row, ".id"),
        chain: rowValue($row, "chain"),
        action: rowValue($row, "action"),
        protocol: rowValue($row, "protocol"),
        srcAddress: rowValue($row, "src-address"),
        dstAddress: rowValue($row, "dst-address"),
        srcAddressList: rowValue($row, "src-address-list"),
        dstAddressList: rowValue($row, "dst-address-list"),
        srcPort: rowValue($row, "src-port"),
        dstPort: rowValue($row, "dst-port"),
        inInterface: rowValue($row, "in-interface"),
        outInterface: rowValue($row, "out-interface"),
        inInterfaceList: rowValue($row, "in-interface-list"),
        outInterfaceList: rowValue($row, "out-interface-list"),
        comment: rowValue($row, "comment"),
        disabled: rowBool($row, "disabled")
    };
}

/**
 * Render a rule as the attribute map "/ip/firewall/filter/add" expects.
 *
 * Unset ("") fields are omitted; a port match without a protocol is
 * rejected because RouterOS would refuse it with a far less friendly
 * message.
 *
 * @param {FirewallRule} rule the rule to render
 * @return {map of string to string} the attribute map
 * @throws {Error} kind "routeros" on an inconsistent rule
 * @internal
 */
func ruleAttrs(rule as FirewallRule) {
    ensureName($rule.chain, "chain");
    ensureAction($rule.action);
    if (($rule.srcPort != "" or $rule.dstPort != "") and $rule.protocol == "") {
        raiseError("a port match needs a protocol - call withProtocol(rule, \"tcp\") or \"udp\" first");
    }
    def attrs as map of string to string init {"chain": $rule.chain, "action": $rule.action};
    if ($rule.protocol != "") {
        $attrs["protocol"] = $rule.protocol;
    }
    if ($rule.srcAddress != "") {
        $attrs["src-address"] = $rule.srcAddress;
    }
    if ($rule.dstAddress != "") {
        $attrs["dst-address"] = $rule.dstAddress;
    }
    if ($rule.srcAddressList != "") {
        $attrs["src-address-list"] = $rule.srcAddressList;
    }
    if ($rule.dstAddressList != "") {
        $attrs["dst-address-list"] = $rule.dstAddressList;
    }
    if ($rule.srcPort != "") {
        $attrs["src-port"] = $rule.srcPort;
    }
    if ($rule.dstPort != "") {
        $attrs["dst-port"] = $rule.dstPort;
    }
    if ($rule.inInterface != "") {
        $attrs["in-interface"] = $rule.inInterface;
    }
    if ($rule.outInterface != "") {
        $attrs["out-interface"] = $rule.outInterface;
    }
    if ($rule.inInterfaceList != "") {
        $attrs["in-interface-list"] = $rule.inInterfaceList;
    }
    if ($rule.outInterfaceList != "") {
        $attrs["out-interface-list"] = $rule.outInterfaceList;
    }
    if ($rule.comment != "") {
        $attrs["comment"] = $rule.comment;
    }
    if ($rule.disabled) {
        $attrs["disabled"] = boolWord($rule.disabled);
    }
    return $attrs;
}
