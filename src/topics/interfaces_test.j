# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the interfaces topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testInterfaceFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "ether1",
        "type": "ether",
        "mac-address": "AA:BB:CC:DD:EE:FF",
        "running": "true",
        "disabled": "false",
        "comment": "uplink"
    };
    def i as Interface init interfaceFromRow($row);
    testing.assertEqual($i.id, "*1");
    testing.assertEqual($i.name, "ether1");
    testing.assertEqual($i.kind, "ether");
    testing.assertEqual($i.mac, "AA:BB:CC:DD:EE:FF");
    testing.assertTrue($i.running);
    testing.assertFalse($i.disabled);
    testing.assertEqual($i.comment, "uplink");
}

func testInterfaceFromSparseRow() {
    def row as map of string to string init {".id": "*7", "name": "lo"};
    def i as Interface init interfaceFromRow($row);
    testing.assertEqual($i.id, "*7");
    testing.assertEqual($i.kind, "");
    testing.assertEqual($i.mac, "");
    testing.assertFalse($i.running);
    testing.assertFalse($i.disabled);
    testing.assertEqual($i.comment, "");
}
