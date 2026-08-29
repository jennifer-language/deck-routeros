# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - firewall raw: drop / notrack before connection tracking.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the firewall raw table. */
export def const RAW_PATH as string init "/ip/firewall/raw";

/**
 * One raw-table rule, as read back from the router.
 *
 * Build rules with the firewall `FirewallRule` builder (its chain must
 * be `CHAIN_PREROUTING` or `CHAIN_OUTPUT`, its action `accept`, `drop`,
 * or `ACTION_NOTRACK`); this struct is the query result.
 *
 * @field {string} id         internal RouterOS id
 * @field {string} chain      "prerouting" or "output"
 * @field {string} action     "accept" / "drop" / "notrack" / ...
 * @field {string} protocol   matched protocol, "" for any
 * @field {string} srcAddress matched source, "" for any
 * @field {string} dstAddress matched destination, "" for any
 * @field {string} srcAddressList source address list, "" for none
 * @field {string} inInterfaceList incoming interface list, "" for none
 * @field {string} comment    free-text comment; the *ByComment handle
 * @field {bool}   disabled   true when switched off
 */
export def struct RawRule {
    id as string,
    chain as string,
    action as string,
    protocol as string,
    srcAddress as string,
    dstAddress as string,
    srcAddressList as string,
    inInterfaceList as string,
    comment as string,
    disabled as bool
};

/**
 * List the firewall raw rules.
 *
 * @param {Client} c an open client
 * @return {list of RawRule} all raw rules
 */
export func rawRules(c as Client) {
    def rows as list of map of string to string init getAll($c, RAW_PATH);
    def out as list of RawRule init [];
    for (def row in $rows) {
        $out[] = rawFromRow($row);
    }
    return $out;
}

/**
 * Create a raw-table rule from a firewall-builder matcher.
 *
 * The raw table runs BEFORE connection tracking, so it is the place to
 * drop obvious garbage cheaply (spoofed sources, bogons, a flood) and
 * to `notrack` traffic that should not fill the connection table. Build
 * the rule with `firewallRule(chain, action)` + the `with*` refiners -
 * the chain must be `CHAIN_PREROUTING` (incoming, the usual choice) or
 * `CHAIN_OUTPUT`, and the action `accept` / `drop` / `ACTION_NOTRACK`.
 *
 * @param {Client}       c    an open client
 * @param {FirewallRule} rule the matcher, built with the firewall builder
 * @return {string} the RouterOS id of the new rule
 * @throws {Error} kind "routeros" on an inconsistent rule
 * @example
 *   def r as mt.FirewallRule init mt.firewallRule(mt.CHAIN_PREROUTING, mt.ACTION_DROP);
 *   $r = mt.withInInterfaceList($r, "WAN");
 *   $r = mt.withSrcAddressList($r, "bogons");
 *   $r = mt.withComment($r, "drop bogons from WAN");
 *   mt.addRawRule($c, $r);
 */
export func addRawRule(c as Client, rule as FirewallRule) {
    return add($c, RAW_PATH, ruleAttrs($rule));
}

/**
 * Drop a source address list early, in raw prerouting (bogon/blocklist
 * filtering at the cheapest point).
 *
 * @param {Client} c        an open client
 * @param {string} listName the address list whose members are dropped
 * @param {string} comment  handle for the rule
 * @return {string} the RouterOS id of the new rule
 * @throws {Error} kind "routeros" on a bad list name
 * @example
 *   mt.dropRawAddressList($c, "bogons", "drop bogons early");
 */
export func dropRawAddressList(c as Client, listName as string, comment as string) {
    def r as FirewallRule init firewallRule(CHAIN_PREROUTING, ACTION_DROP);
    $r = withSrcAddressList($r, $listName);
    $r = withComment($r, $comment);
    return addRawRule($c, $r);
}

/**
 * Delete a raw rule by its RouterOS id.
 *
 * @param {Client} c  an open client
 * @param {string} id the rule id
 */
export func removeRawRule(c as Client, id as string) {
    remove($c, RAW_PATH, $id);
}

/**
 * Delete the raw rule that carries a comment.
 *
 * @param {Client} c       an open client
 * @param {string} comment the rule's comment
 * @throws {Error} kind "routeros" when no raw rule carries that comment
 */
export func removeRawRuleByComment(c as Client, comment as string) {
    remove($c, RAW_PATH, rawIdByComment($c, $comment));
}

/**
 * Move a raw rule so it is evaluated directly before another one.
 *
 * The raw table is the cheapest place to drop traffic, and inside it
 * order still decides: a `notrack` above a `drop` spares the connection
 * tracker work the `drop` would have made pointless.
 *
 * @param {Client} c        an open client
 * @param {string} id       the rule to move
 * @param {string} beforeId the rule it must end up above, "" for the bottom
 * @throws {Error} kind "routeros" on an empty id or a self-move
 */
export func moveRawRule(c as Client, id as string, beforeId as string) {
    moveRule($c, RAW_PATH, $id, $beforeId);
}

/**
 * Move the raw rule carrying one comment above the rule carrying another.
 *
 * @param {Client} c             an open client
 * @param {string} comment       the rule to move
 * @param {string} beforeComment the rule it must end up above, "" for the bottom
 * @throws {Error} kind "routeros" when either comment matches no rule
 */
export func moveRawRuleByComment(c as Client, comment as string, beforeComment as string) {
    def target as string init rawIdByComment($c, $comment);
    def dest as string init "";
    if (strings.trim($beforeComment) != "") {
        $dest = rawIdByComment($c, $beforeComment);
    }
    moveRule($c, RAW_PATH, $target, $dest);
}

/**
 * Resolve a raw rule comment to the rule's id.
 *
 * @param {Client} c       an open client
 * @param {string} comment the rule's comment
 * @return {string} the rule id
 * @throws {Error} kind "routeros" when no raw rule carries that comment
 * @internal
 */
func rawIdByComment(c as Client, comment as string) {
    return requiredIdByComment($c, RAW_PATH, $comment, "raw rule");
}

/**
 * Fold a reply row into a RawRule.
 *
 * @param {map of string to string} row an "/ip/firewall/raw/print" row
 * @return {RawRule} the typed rule
 * @internal
 */
func rawFromRow(row as map of string to string) {
    return RawRule{
        id: rowValue($row, ".id"),
        chain: rowValue($row, "chain"),
        action: rowValue($row, "action"),
        protocol: rowValue($row, "protocol"),
        srcAddress: rowValue($row, "src-address"),
        dstAddress: rowValue($row, "dst-address"),
        srcAddressList: rowValue($row, "src-address-list"),
        inInterfaceList: rowValue($row, "in-interface-list"),
        comment: rowValue($row, "comment"),
        disabled: rowBool($row, "disabled")
    };
}
