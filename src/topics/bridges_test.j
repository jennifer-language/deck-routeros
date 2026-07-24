# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the bridges topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testBridgeFromRow() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "brlan",
        "mac-address": "AA:BB:CC:00:11:22",
        "running": "yes",
        "disabled": "no",
        "comment": "house lan"
    };
    def b as Bridge init bridgeFromRow($row);
    testing.assertEqual($b.id, "*2");
    testing.assertEqual($b.name, "brlan");
    testing.assertEqual($b.mac, "AA:BB:CC:00:11:22");
    testing.assertTrue($b.running);
    testing.assertFalse($b.disabled);
    testing.assertEqual($b.comment, "house lan");
}

func testBridgePortFromRow() {
    def row as map of string to string init {
        ".id": "*3",
        "bridge": "brlan",
        "interface": "ether2",
        "disabled": "false"
    };
    def p as BridgePort init bridgePortFromRow($row);
    testing.assertEqual($p.id, "*3");
    testing.assertEqual($p.bridge, "brlan");
    testing.assertEqual($p.interfaceName, "ether2");
    testing.assertFalse($p.disabled);
}

func testBridgeVlanFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "bridge": "brlan",
        "vlan-ids": "10",
        "tagged": "ether1,brlan",
        "untagged": "ether2,ether3",
        "dynamic": "false"
    };
    def bv as BridgeVlan init bridgeVlanFromRow($row);
    testing.assertEqual($bv.bridge, "brlan");
    testing.assertEqual($bv.vlanIds, "10");
    testing.assertEqual($bv.tagged, "ether1,brlan");
    testing.assertEqual($bv.untagged, "ether2,ether3");
    testing.assertFalse($bv.dynamic);
}

func testNormalizedPortListForms() {
    testing.assertEqual(normalizedPortList("ether1"), "ether1");
    testing.assertEqual(normalizedPortList(" ether1 , ether2 "), "ether1,ether2");
}

func failPortListSpaced() {
    normalizedPortList("ether 1");
}

func testNormalizedPortListRejectsSpaced() {
    testing.assertThrows("failPortListSpaced", "routeros");
}

func testFindBridgeVlanRowMatchesBoth() {
    def rows as list of map of string to string init [
        {".id": "*1", "bridge": "brlan", "vlan-ids": "10"},
        {".id": "*2", "bridge": "brguest", "vlan-ids": "10"},
        {".id": "*3", "bridge": "brlan", "vlan-ids": "20"}
    ];
    def row as map of string to string init findBridgeVlanRow($rows, "brlan", "20");
    testing.assertEqual(rowValue($row, ".id"), "*3");
}

func testBridgePortRowMatchesBridgeAndPort() {
    def rows as list of map of string to string init [
        {".id": "*1", "bridge": "brlan", "interface": "ether2"},
        {".id": "*2", "bridge": "brlan", "interface": "ether3"}
    ];
    def row as map of string to string init bridgePortRow($rows, "brlan", "ether3");
    testing.assertEqual(rowValue($row, ".id"), "*2");
    def miss as map of string to string init bridgePortRow($rows, "brguest", "ether2");
    testing.assertEqual(len($miss), 0);
}

func testBridgePortFromRowHardwareOffload() {
    def row as map of string to string init {
        ".id": "*1",
        "bridge": "brlan",
        "interface": "ether2",
        "hw": "yes",
        "disabled": "false"
    };
    def p as BridgePort init bridgePortFromRow($row);
    testing.assertEqual($p.bridge, "brlan");
    testing.assertEqual($p.interfaceName, "ether2");
    testing.assertTrue($p.hardwareOffload);
    testing.assertFalse($p.disabled);
}

func testBridgePortFromRowSoftwareForwarding() {
    def row as map of string to string init {
        ".id": "*2",
        "bridge": "brlan",
        "interface": "vlanoffice",
        "hw": "no"
    };
    def p as BridgePort init bridgePortFromRow($row);
    testing.assertFalse($p.hardwareOffload);
}
