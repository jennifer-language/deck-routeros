# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the interfacelist topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testInterfaceListFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "WAN",
        "dynamic": "false",
        "comment": "internet-facing"
    };
    def il as InterfaceList init interfaceListFromRow($row);
    testing.assertEqual($il.id, "*1");
    testing.assertEqual($il.name, "WAN");
    testing.assertFalse($il.dynamic);
    testing.assertEqual($il.comment, "internet-facing");
}

func testMemberRowMatchesListAndInterface() {
    def rows as list of map of string to string init [
        {".id": "*1", "list": "WAN", "interface": "ether1"},
        {".id": "*2", "list": "LAN", "interface": "ether2"},
        {".id": "*3", "list": "LAN", "interface": "ether3"}
    ];
    def row as map of string to string init memberRow($rows, "LAN", "ether3");
    testing.assertEqual(rowValue($row, ".id"), "*3");
    def miss as map of string to string init memberRow($rows, "WAN", "ether2");
    testing.assertEqual(len($miss), 0);
}
