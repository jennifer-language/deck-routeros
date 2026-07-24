# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the ethernet topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testEthernetFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "uplink",
        "default-name": "ether1",
        "mac-address": "AA:BB:CC:DD:EE:01",
        "mtu": "1500",
        "auto-negotiation": "true",
        "poe-out": "auto-on",
        "running": "true",
        "slave": "false",
        "disabled": "false",
        "comment": "to the switch"
    };
    def p as EthernetPort init ethernetFromRow($row);
    testing.assertEqual($p.id, "*1");
    testing.assertEqual($p.name, "uplink");
    testing.assertEqual($p.defaultName, "ether1");
    testing.assertEqual($p.mac, "AA:BB:CC:DD:EE:01");
    testing.assertEqual($p.mtu, "1500");
    testing.assertTrue($p.autoNegotiation);
    testing.assertEqual($p.poeOut, "auto-on");
    testing.assertTrue($p.running);
    testing.assertFalse($p.slave);
    testing.assertFalse($p.disabled);
    testing.assertEqual($p.comment, "to the switch");
}

func testEthernetFromRowBridgeSlaveNoPoe() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "ether2",
        "default-name": "ether2",
        "slave": "true",
        "running": "false"
    };
    def p as EthernetPort init ethernetFromRow($row);
    testing.assertTrue($p.slave);
    testing.assertFalse($p.running);
    testing.assertEqual($p.poeOut, "");
    testing.assertFalse($p.autoNegotiation);
}

func testLinkStatusFromRowUp() {
    def row as map of string to string init {
        "name": "ether1",
        "status": "link-ok",
        "rate": "1Gbps",
        "full-duplex": "true",
        "auto-negotiation": "done"
    };
    def ls as LinkStatus init linkStatusFromRow($row);
    testing.assertEqual($ls.name, "ether1");
    testing.assertTrue($ls.up);
    testing.assertEqual($ls.status, "link-ok");
    testing.assertEqual($ls.rate, "1Gbps");
    testing.assertTrue($ls.fullDuplex);
    testing.assertEqual($ls.autoNegotiation, "done");
}

func testLinkStatusFromRowDown() {
    def row as map of string to string init {
        "name": "ether5",
        "status": "no-link"
    };
    def ls as LinkStatus init linkStatusFromRow($row);
    testing.assertFalse($ls.up);
    testing.assertEqual($ls.status, "no-link");
    testing.assertEqual($ls.rate, "");
    testing.assertFalse($ls.fullDuplex);
}

func testEnsureEthernetSpeedAcceptsKnown() {
    ensureEthernetSpeed("10Mbps");
    ensureEthernetSpeed("100Mbps");
    ensureEthernetSpeed("1Gbps");
    ensureEthernetSpeed("10Gbps");
    testing.assertTrue(true);
}

func failEthernetSpeedUnknown() {
    ensureEthernetSpeed("11Gbps");
}

func testEnsureEthernetSpeedRejectsUnknown() {
    testing.assertThrows("failEthernetSpeedUnknown", "routeros");
}

func failEthernetSpeedBareNumber() {
    ensureEthernetSpeed("1000");
}

func testEnsureEthernetSpeedRejectsBareNumber() {
    testing.assertThrows("failEthernetSpeedBareNumber", "routeros");
}

func testEnsurePoeModeAcceptsKnown() {
    ensurePoeMode("auto-on");
    ensurePoeMode("forced-on");
    ensurePoeMode("off");
    testing.assertTrue(true);
}

func failPoeModeUnknown() {
    ensurePoeMode("on");
}

func testEnsurePoeModeRejectsUnknown() {
    testing.assertThrows("failPoeModeUnknown", "routeros");
}

func testEnsureMtuAcceptsBounds() {
    ensureMtu(68);
    ensureMtu(1500);
    ensureMtu(9000);
    ensureMtu(65535);
    testing.assertTrue(true);
}

func failMtuTooSmall() {
    ensureMtu(67);
}

func testEnsureMtuRejectsTooSmall() {
    testing.assertThrows("failMtuTooSmall", "routeros");
}

func failMtuTooBig() {
    ensureMtu(65536);
}

func testEnsureMtuRejectsTooBig() {
    testing.assertThrows("failMtuTooBig", "routeros");
}
