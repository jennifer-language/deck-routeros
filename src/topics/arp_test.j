# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the arp topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testArpFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "address": "192.168.88.50",
        "mac-address": "AA:BB:CC:DD:EE:FF",
        "interface": "brlan",
        "dynamic": "true",
        "complete": "true",
        "published": "false",
        "disabled": "false",
        "comment": ""
    };
    def a as ArpEntry init arpFromRow($row);
    testing.assertEqual($a.id, "*1");
    testing.assertEqual($a.address, "192.168.88.50");
    testing.assertEqual($a.mac, "AA:BB:CC:DD:EE:FF");
    testing.assertEqual($a.interfaceName, "brlan");
    testing.assertTrue($a.dynamic);
    testing.assertTrue($a.complete);
    testing.assertFalse($a.published);
    testing.assertFalse($a.disabled);
}

func testArpFromRowUnresolved() {
    def row as map of string to string init {
        ".id": "*2",
        "address": "192.168.88.99",
        "interface": "brlan",
        "dynamic": "true",
        "complete": "false"
    };
    def a as ArpEntry init arpFromRow($row);
    testing.assertEqual($a.mac, "");
    testing.assertFalse($a.complete);
    testing.assertEqual($a.comment, "");
}

func testAddressesForMacRowsIsCaseInsensitive() {
    def rows as list of map of string to string init [
        {"address": "192.168.88.50", "mac-address": "AA:BB:CC:DD:EE:FF"},
        {"address": "192.168.88.60", "mac-address": "11:22:33:44:55:66"},
        {"address": "10.20.0.50", "mac-address": "aa:bb:cc:dd:ee:ff"}
    ];
    def addrs as list of string init addressesForMacRows($rows, "aa:bb:cc:dd:ee:ff");
    testing.assertEqual(len($addrs), 2);
    testing.assertEqual($addrs[0], "192.168.88.50");
    testing.assertEqual($addrs[1], "10.20.0.50");
}

func testAddressesForMacRowsMissIsEmpty() {
    def rows as list of map of string to string init [
        {"address": "192.168.88.50", "mac-address": "AA:BB:CC:DD:EE:FF"}
    ];
    def addrs as list of string init addressesForMacRows($rows, "11:22:33:44:55:66");
    testing.assertEqual(len($addrs), 0);
}

func testFindStaticArpRowSkipsDynamic() {
    def rows as list of map of string to string init [
        {".id": "*1", "address": "192.168.88.50", "interface": "brlan", "dynamic": "true"},
        {".id": "*2", "address": "192.168.88.50", "interface": "brlan", "dynamic": "false"}
    ];
    def row as map of string to string init
        findStaticArpRow($rows, "192.168.88.50", "brlan");
    testing.assertEqual(rowValue($row, ".id"), "*2");
}

func testFindStaticArpRowChecksInterface() {
    def rows as list of map of string to string init [
        {".id": "*1", "address": "192.168.88.50", "interface": "brguest", "dynamic": "false"}
    ];
    def row as map of string to string init
        findStaticArpRow($rows, "192.168.88.50", "brlan");
    testing.assertEqual(len($row), 0);
}

func testFindStaticArpRowMissingDynamicKeyIsStatic() {
    def rows as list of map of string to string init [
        {".id": "*1", "address": "10.0.0.1", "interface": "ether2"}
    ];
    def row as map of string to string init findStaticArpRow($rows, "10.0.0.1", "ether2");
    testing.assertEqual(rowValue($row, ".id"), "*1");
}
