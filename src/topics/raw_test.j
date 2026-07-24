# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the raw topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testRawFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "chain": "prerouting",
        "action": "drop",
        "protocol": "tcp",
        "src-address": "203.0.113.0/24",
        "src-address-list": "bogons",
        "in-interface-list": "WAN",
        "comment": "drop bogons from WAN",
        "disabled": "false"
    };
    def r as RawRule init rawFromRow($row);
    testing.assertEqual($r.chain, "prerouting");
    testing.assertEqual($r.action, "drop");
    testing.assertEqual($r.srcAddressList, "bogons");
    testing.assertEqual($r.inInterfaceList, "WAN");
    testing.assertEqual($r.comment, "drop bogons from WAN");
    testing.assertFalse($r.disabled);
}

func testRawFromRowNotrack() {
    def row as map of string to string init {
        ".id": "*2",
        "chain": "prerouting",
        "action": "notrack",
        "dst-address": "224.0.0.0/4"
    };
    def r as RawRule init rawFromRow($row);
    testing.assertEqual($r.action, "notrack");
    testing.assertEqual($r.dstAddress, "224.0.0.0/4");
    testing.assertEqual($r.srcAddressList, "");
}

# notrack is a valid firewall builder action (raw-only in practice)
func testFirewallRuleAcceptsNotrackAction() {
    def r as FirewallRule init firewallRule("prerouting", "notrack");
    testing.assertEqual($r.action, "notrack");
}

func testWithInterfaceListMatchers() {
    def r as FirewallRule init firewallRule("prerouting", "drop");
    $r = withInInterfaceList($r, "WAN");
    $r = withOutInterfaceList($r, "LAN");
    testing.assertEqual($r.inInterfaceList, "WAN");
    testing.assertEqual($r.outInterfaceList, "LAN");
    def attrs as map of string to string init ruleAttrs($r);
    testing.assertEqual($attrs["in-interface-list"], "WAN");
    testing.assertEqual($attrs["out-interface-list"], "LAN");
}
