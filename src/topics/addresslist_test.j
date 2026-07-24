# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the addresslist topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testEnsureListAddressAcceptsForms() {
    ensureListAddress("203.0.113.7");
    ensureListAddress("203.0.113.0/24");
    ensureListAddress("bad.example.org");
    ensureListAddress("2001:db8::1");
    testing.assertTrue(true);
}

func failListAddressWithSpaces() {
    ensureListAddress("bad host");
}

func testEnsureListAddressRejectsSpaces() {
    testing.assertThrows("failListAddressWithSpaces", "routeros");
}

func failListAddressBadCidr() {
    ensureListAddress("203.0.113.0/99");
}

func testEnsureListAddressRejectsBadCidr() {
    testing.assertThrows("failListAddressBadCidr", "routeros");
}

func testFindAddressListRowMatchesListAndAddress() {
    def rows as list of map of string to string init [
        {".id": "*1", "list": "blocklist", "address": "203.0.113.7"},
        {".id": "*2", "list": "vpnusers", "address": "203.0.113.7"},
        {".id": "*3", "list": "blocklist", "address": "198.51.100.1"}
    ];
    def row as map of string to string init
        findAddressListRow($rows, "blocklist", "198.51.100.1");
    testing.assertEqual(rowValue($row, ".id"), "*3");
}

func testFindAddressListRowMissesWrongList() {
    def rows as list of map of string to string init [
        {".id": "*1", "list": "vpnusers", "address": "203.0.113.7"}
    ];
    def row as map of string to string init
        findAddressListRow($rows, "blocklist", "203.0.113.7");
    testing.assertEqual(len($row), 0);
}

func testDistinctListsDeduplicatesInOrder() {
    def rows as list of map of string to string init [
        {".id": "*1", "list": "blocklist", "address": "203.0.113.7"},
        {".id": "*2", "list": "vpnusers", "address": "10.100.0.2"},
        {".id": "*3", "list": "blocklist", "address": "198.51.100.1"}
    ];
    def names as list of string init distinctLists($rows);
    testing.assertEqual(len($names), 2);
    testing.assertEqual($names[0], "blocklist");
    testing.assertEqual($names[1], "vpnusers");
}

func testDistinctListsEmptyRows() {
    def rows as list of map of string to string init [];
    testing.assertEqual(len(distinctLists($rows)), 0);
}

func testAddressListEntryFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "list": "blocklist",
        "address": "203.0.113.7",
        "timeout": "23h59m50s",
        "dynamic": "false",
        "disabled": "false",
        "comment": "ssh scanner"
    };
    def a as AddressListEntry init addressListEntryFromRow($row);
    testing.assertEqual($a.id, "*1");
    testing.assertEqual($a.listName, "blocklist");
    testing.assertEqual($a.address, "203.0.113.7");
    testing.assertEqual($a.timeout, "23h59m50s");
    testing.assertFalse($a.dynamic);
    testing.assertFalse($a.disabled);
    testing.assertEqual($a.comment, "ssh scanner");
}

func testAddressListEntryFromSparseRow() {
    def row as map of string to string init {
        ".id": "*2",
        "list": "vpnusers",
        "address": "10.100.0.0/24"
    };
    def a as AddressListEntry init addressListEntryFromRow($row);
    testing.assertEqual($a.timeout, "");
    testing.assertFalse($a.dynamic);
    testing.assertEqual($a.comment, "");
}
