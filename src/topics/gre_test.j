# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the gre topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testGreFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "grebranch",
        "remote-address": "203.0.113.99",
        "local-address": "198.51.100.1",
        "mtu": "1476",
        "keepalive": "10s,10",
        "running": "true",
        "disabled": "false",
        "comment": "routed link to branch"
    };
    def t as GreTunnel init greFromRow($row);
    testing.assertEqual($t.id, "*1");
    testing.assertEqual($t.name, "grebranch");
    testing.assertEqual($t.remoteAddress, "203.0.113.99");
    testing.assertEqual($t.localAddress, "198.51.100.1");
    testing.assertEqual($t.mtu, "1476");
    testing.assertEqual($t.keepalive, "10s,10");
    testing.assertTrue($t.running);
    testing.assertFalse($t.disabled);
    testing.assertEqual($t.comment, "routed link to branch");
}

func testGreFromSparseRow() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "grelab",
        "remote-address": "192.0.2.9"
    };
    def t as GreTunnel init greFromRow($row);
    testing.assertEqual($t.localAddress, "");
    testing.assertEqual($t.keepalive, "");
    testing.assertFalse($t.running);
    testing.assertEqual($t.comment, "");
}
