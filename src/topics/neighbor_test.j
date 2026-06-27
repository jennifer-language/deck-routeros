# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the neighbor topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testNeighborFromRow() {
    def row as map of string to string init {
        "interface": "ether2",
        "address": "10.0.9.31",
        "mac-address": "AA:BB:CC:DD:EE:31",
        "identity": "sw-lobby",
        "platform": "MikroTik",
        "board": "CRS328",
        "version": "7.15.2"
    };
    def n as Neighbor init neighborFromRow($row);
    testing.assertEqual($n.interfaceName, "ether2");
    testing.assertEqual($n.address, "10.0.9.31");
    testing.assertEqual($n.mac, "AA:BB:CC:DD:EE:31");
    testing.assertEqual($n.identity, "sw-lobby");
    testing.assertEqual($n.platform, "MikroTik");
    testing.assertEqual($n.board, "CRS328");
    testing.assertEqual($n.version, "7.15.2");
}

func testNeighborFromLayer2Row() {
    def row as map of string to string init {
        "interface": "ether1",
        "mac-address": "AA:BB:CC:DD:EE:01",
        "platform": "Cisco"
    };
    def n as Neighbor init neighborFromRow($row);
    testing.assertEqual($n.address, "");
    testing.assertEqual($n.platform, "Cisco");
}
