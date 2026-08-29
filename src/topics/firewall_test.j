# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the firewall topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func failEnsureActionUnknown() {
    ensureAction("frobnicate");
}

func testEnsureActionRejectsUnknown() {
    testing.assertThrows("failEnsureActionUnknown", "routeros");
}

func failEnsureProtocolUnknown() {
    ensureProtocol("carrier-pigeon");
}

func testEnsureProtocolRejectsUnknown() {
    testing.assertThrows("failEnsureProtocolUnknown", "routeros");
}

func testFirewallRuleFromRow() {
    def row as map of string to string init {
        ".id": "*A",
        "chain": "input",
        "action": "accept",
        "protocol": "tcp",
        "src-address": "10.0.0.0/8",
        "dst-address": "192.168.88.1",
        "src-port": "1024-65535",
        "dst-port": "22,443",
        "in-interface": "ether1",
        "out-interface": "brlan",
        "comment": "management",
        "disabled": "true"
    };
    def r as FirewallRule init firewallRuleFromRow($row);
    testing.assertEqual($r.id, "*A");
    testing.assertEqual($r.chain, "input");
    testing.assertEqual($r.action, "accept");
    testing.assertEqual($r.protocol, "tcp");
    testing.assertEqual($r.srcAddress, "10.0.0.0/8");
    testing.assertEqual($r.dstAddress, "192.168.88.1");
    testing.assertEqual($r.srcPort, "1024-65535");
    testing.assertEqual($r.dstPort, "22,443");
    testing.assertEqual($r.inInterface, "ether1");
    testing.assertEqual($r.outInterface, "brlan");
    testing.assertEqual($r.comment, "management");
    testing.assertTrue($r.disabled);
}

func testFirewallRuleStartsBlank() {
    def r as FirewallRule init firewallRule("input", "accept");
    testing.assertEqual($r.chain, "input");
    testing.assertEqual($r.action, "accept");
    testing.assertEqual($r.id, "");
    testing.assertEqual($r.protocol, "");
    testing.assertEqual($r.srcAddress, "");
    testing.assertEqual($r.dstPort, "");
    testing.assertEqual($r.comment, "");
    testing.assertFalse($r.disabled);
}

func testFirewallRuleAcceptsCustomChain() {
    def r as FirewallRule init firewallRule("myservices", "drop");
    testing.assertEqual($r.chain, "myservices");
}

func failFirewallRuleBadAction() {
    firewallRule("input", "explode");
}

func testFirewallRuleRejectsBadAction() {
    testing.assertThrows("failFirewallRuleBadAction", "routeros");
}

func failFirewallRuleEmptyChain() {
    firewallRule("", "accept");
}

func testFirewallRuleRejectsEmptyChain() {
    testing.assertThrows("failFirewallRuleEmptyChain", "routeros");
}

func testWithHelpersRefine() {
    def r as FirewallRule init firewallRule("forward", "drop");
    $r = withProtocol($r, "tcp");
    $r = withSrcAddress($r, "10.0.0.0/8");
    $r = withDstAddress($r, "192.168.88.0/24");
    $r = withSrcPort($r, "1024-65535");
    $r = withDstPort($r, "445");
    $r = withInInterface($r, "ether1");
    $r = withOutInterface($r, "brlan");
    $r = withComment($r, "no smb across segments");
    $r = withDisabled($r, true);
    testing.assertEqual($r.protocol, "tcp");
    testing.assertEqual($r.srcAddress, "10.0.0.0/8");
    testing.assertEqual($r.dstAddress, "192.168.88.0/24");
    testing.assertEqual($r.srcPort, "1024-65535");
    testing.assertEqual($r.dstPort, "445");
    testing.assertEqual($r.inInterface, "ether1");
    testing.assertEqual($r.outInterface, "brlan");
    testing.assertEqual($r.comment, "no smb across segments");
    testing.assertTrue($r.disabled);
}

func testWithHelpersCopyNotMutate() {
    def base as FirewallRule init firewallRule("input", "accept");
    def refined as FirewallRule init withProtocol($base, "udp");
    testing.assertEqual($refined.protocol, "udp");
    testing.assertEqual($base.protocol, "");
}

func testWithAddressListMatchers() {
    def r as FirewallRule init firewallRule("input", "drop");
    $r = withSrcAddressList($r, "blocklist");
    $r = withDstAddressList($r, "honeypots");
    testing.assertEqual($r.srcAddressList, "blocklist");
    testing.assertEqual($r.dstAddressList, "honeypots");
    def attrs as map of string to string init ruleAttrs($r);
    testing.assertEqual($attrs["src-address-list"], "blocklist");
    testing.assertEqual($attrs["dst-address-list"], "honeypots");
    testing.assertEqual(len($attrs), 4);
}

func failWithSrcAddressListEmpty() {
    withSrcAddressList(firewallRule("input", "drop"), "  ");
}

func testWithSrcAddressListRejectsEmpty() {
    testing.assertThrows("failWithSrcAddressListEmpty", "routeros");
}

func testRuleAttrsMinimal() {
    def r as FirewallRule init firewallRule("input", "accept");
    def attrs as map of string to string init ruleAttrs($r);
    testing.assertEqual(len($attrs), 2);
    testing.assertEqual($attrs["chain"], "input");
    testing.assertEqual($attrs["action"], "accept");
}

func testRuleAttrsFull() {
    def r as FirewallRule init firewallRule("forward", "drop");
    $r = withProtocol($r, "tcp");
    $r = withSrcAddress($r, "203.0.113.0/24");
    $r = withDstAddress($r, "192.168.88.10");
    $r = withSrcPort($r, "1024-65535");
    $r = withDstPort($r, "80,443");
    $r = withInInterface($r, "ether1");
    $r = withOutInterface($r, "brlan");
    $r = withComment($r, "block web to server");
    $r = withDisabled($r, true);
    def attrs as map of string to string init ruleAttrs($r);
    testing.assertEqual($attrs["chain"], "forward");
    testing.assertEqual($attrs["action"], "drop");
    testing.assertEqual($attrs["protocol"], "tcp");
    testing.assertEqual($attrs["src-address"], "203.0.113.0/24");
    testing.assertEqual($attrs["dst-address"], "192.168.88.10");
    testing.assertEqual($attrs["src-port"], "1024-65535");
    testing.assertEqual($attrs["dst-port"], "80,443");
    testing.assertEqual($attrs["in-interface"], "ether1");
    testing.assertEqual($attrs["out-interface"], "brlan");
    testing.assertEqual($attrs["comment"], "block web to server");
    testing.assertEqual($attrs["disabled"], "yes");
    testing.assertEqual(len($attrs), 11);
}

func testRuleAttrsOmitsUnsetFields() {
    def r as FirewallRule init firewallRule("input", "drop");
    $r = withSrcAddress($r, "203.0.113.7");
    def attrs as map of string to string init ruleAttrs($r);
    testing.assertEqual(len($attrs), 3);
    testing.assertContains($attrs, "chain");
    testing.assertContains($attrs, "action");
    testing.assertContains($attrs, "src-address");
    testing.assertEqual(rowValue($attrs, "protocol"), "");
    testing.assertEqual(rowValue($attrs, "disabled"), "");
}

func failRuleAttrsPortWithoutProtocol() {
    def r as FirewallRule init firewallRule("input", "accept");
    $r = withDstPort($r, "80");
    ruleAttrs($r);
}

func testRuleAttrsRejectsPortWithoutProtocol() {
    testing.assertThrows("failRuleAttrsPortWithoutProtocol", "routeros");
}
