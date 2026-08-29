# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the mangle topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testMangleFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "chain": "prerouting",
        "action": "mark-packet",
        "connection-mark": "voip-conn",
        "new-packet-mark": "voip",
        "passthrough": "false",
        "disabled": "false",
        "comment": "mark: voip (packets)"
    };
    def m as MangleRule init mangleFromRow($row);
    testing.assertEqual($m.id, "*1");
    testing.assertEqual($m.chain, "prerouting");
    testing.assertEqual($m.action, "mark-packet");
    testing.assertEqual($m.connectionMark, "voip-conn");
    testing.assertEqual($m.newPacketMark, "voip");
    testing.assertFalse($m.passthrough);
    testing.assertEqual($m.comment, "mark: voip (packets)");
}

func testMangleFromRowMssClamp() {
    def row as map of string to string init {
        ".id": "*2",
        "chain": "forward",
        "action": "change-mss",
        "protocol": "tcp",
        "new-mss": "clamp-to-pmtu",
        "out-interface": "pppoewan",
        "passthrough": "true"
    };
    def m as MangleRule init mangleFromRow($row);
    testing.assertEqual($m.action, "change-mss");
    testing.assertEqual($m.newMss, "clamp-to-pmtu");
    testing.assertEqual($m.outInterface, "pppoewan");
    testing.assertTrue($m.passthrough);
    testing.assertEqual($m.newPacketMark, "");
}

func testPacketMarkRuleAttrsPair() {
    def matcher as FirewallRule init firewallRule("prerouting", "accept");
    $matcher = withProtocol($matcher, "udp");
    $matcher = withDstPort($matcher, "5060-5200");
    def pair as list of map of string to string init packetMarkRuleAttrs($matcher, "voip");
    testing.assertEqual(len($pair), 2);
    def conn as map of string to string init $pair[0];
    testing.assertEqual($conn["chain"], "prerouting");
    testing.assertEqual($conn["action"], "mark-connection");
    testing.assertEqual($conn["protocol"], "udp");
    testing.assertEqual($conn["dst-port"], "5060-5200");
    testing.assertEqual($conn["new-connection-mark"], "voip-conn");
    testing.assertEqual($conn["connection-state"], "new");
    testing.assertEqual($conn["passthrough"], "yes");
    testing.assertEqual($conn["comment"], "mark: voip (connections)");
    def pkt as map of string to string init $pair[1];
    testing.assertEqual($pkt["chain"], "prerouting");
    testing.assertEqual($pkt["action"], "mark-packet");
    testing.assertEqual($pkt["connection-mark"], "voip-conn");
    testing.assertEqual($pkt["new-packet-mark"], "voip");
    testing.assertEqual($pkt["passthrough"], "no");
    testing.assertEqual($pkt["comment"], "mark: voip (packets)");
    testing.assertEqual(rowValue($pkt, "protocol"), "");
}

func testRoutingMarkAttrs() {
    def attrs as map of string to string init routingMarkAttrs("backupisp", "10.30.0.0/24");
    testing.assertEqual($attrs["chain"], "prerouting");
    testing.assertEqual($attrs["action"], "mark-routing");
    testing.assertEqual($attrs["src-address"], "10.30.0.0/24");
    testing.assertEqual($attrs["new-routing-mark"], "backupisp");
    testing.assertEqual($attrs["passthrough"], "yes");
    testing.assertEqual($attrs["comment"], "route mark: backupisp for 10.30.0.0/24");
}

func testMssClampAttrsDirections() {
    def outAttrs as map of string to string init mssClampAttrs("pppoewan", "out");
    testing.assertEqual($outAttrs["chain"], "forward");
    testing.assertEqual($outAttrs["action"], "change-mss");
    testing.assertEqual($outAttrs["protocol"], "tcp");
    testing.assertEqual($outAttrs["tcp-flags"], "syn");
    testing.assertEqual($outAttrs["new-mss"], "clamp-to-pmtu");
    testing.assertEqual($outAttrs["out-interface"], "pppoewan");
    testing.assertEqual(rowValue($outAttrs, "in-interface"), "");
    def inAttrs as map of string to string init mssClampAttrs("pppoewan", "in");
    testing.assertEqual($inAttrs["in-interface"], "pppoewan");
    testing.assertEqual(rowValue($inAttrs, "out-interface"), "");
    testing.assertEqual($inAttrs["comment"], "mss clamp: pppoewan (in)");
}
