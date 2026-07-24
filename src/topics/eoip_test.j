# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the eoip topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testEoipFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "eoipbranch",
        "remote-address": "10.100.0.2",
        "local-address": "10.100.0.1",
        "tunnel-id": "7",
        "mac-address": "FE:AA:BB:CC:DD:EE",
        "mtu": "1458",
        "keepalive": "10s,10",
        "running": "true",
        "disabled": "false",
        "comment": "to the branch"
    };
    def t as EoipTunnel init eoipFromRow($row);
    testing.assertEqual($t.id, "*1");
    testing.assertEqual($t.name, "eoipbranch");
    testing.assertEqual($t.remoteAddress, "10.100.0.2");
    testing.assertEqual($t.localAddress, "10.100.0.1");
    testing.assertEqual($t.tunnelId, 7);
    testing.assertEqual($t.mac, "FE:AA:BB:CC:DD:EE");
    testing.assertEqual($t.mtu, "1458");
    testing.assertEqual($t.keepalive, "10s,10");
    testing.assertTrue($t.running);
    testing.assertFalse($t.disabled);
    testing.assertEqual($t.comment, "to the branch");
}

func testEoipFromSparseRow() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "eoiplab",
        "remote-address": "192.0.2.9",
        "tunnel-id": "0"
    };
    def t as EoipTunnel init eoipFromRow($row);
    testing.assertEqual($t.tunnelId, 0);
    testing.assertEqual($t.localAddress, "");
    testing.assertFalse($t.running);
    testing.assertEqual($t.comment, "");
}

func testEnsureTunnelIdAcceptsBounds() {
    ensureTunnelId(0);
    ensureTunnelId(7);
    ensureTunnelId(65535);
    testing.assertTrue(true);
}

func failTunnelIdNegative() {
    ensureTunnelId(-1);
}

func testEnsureTunnelIdRejectsNegative() {
    testing.assertThrows("failTunnelIdNegative", "routeros");
}

func failTunnelIdTooBig() {
    ensureTunnelId(65536);
}

func testEnsureTunnelIdRejectsTooBig() {
    testing.assertThrows("failTunnelIdTooBig", "routeros");
}

func testFindEoipRowMatchesRemoteAndId() {
    def rows as list of map of string to string init [
        {".id": "*1", "name": "eoipa", "remote-address": "10.100.0.2", "tunnel-id": "7"},
        {".id": "*2", "name": "eoipb", "remote-address": "10.100.0.3", "tunnel-id": "7"}
    ];
    def row as map of string to string init findEoipRow($rows, "10.100.0.3", 7);
    testing.assertEqual(rowValue($row, "name"), "eoipb");
}

func testFindEoipRowIdMismatchIsMiss() {
    def rows as list of map of string to string init [
        {".id": "*1", "name": "eoipa", "remote-address": "10.100.0.2", "tunnel-id": "7"}
    ];
    def row as map of string to string init findEoipRow($rows, "10.100.0.2", 8);
    testing.assertEqual(len($row), 0);
}

func testFindEoipRowRemoteMismatchIsMiss() {
    def rows as list of map of string to string init [
        {".id": "*1", "name": "eoipa", "remote-address": "10.100.0.2", "tunnel-id": "7"}
    ];
    def row as map of string to string init findEoipRow($rows, "10.100.0.9", 7);
    testing.assertEqual(len($row), 0);
}
