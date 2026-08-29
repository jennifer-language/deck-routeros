# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the netwatch topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testNetwatchFromRowUp() {
    def row as map of string to string init {
        ".id": "*1",
        "host": "192.168.88.50",
        "status": "up",
        "since": "2026-07-24 08:00:01",
        "interval": "10s",
        "timeout": "1s",
        "up-script": ":log info \"printer back\"",
        "down-script": ":log warning \"printer down\"",
        "disabled": "false",
        "comment": "printer"
    };
    def n as NetwatchHost init netwatchFromRow($row);
    testing.assertEqual($n.id, "*1");
    testing.assertEqual($n.host, "192.168.88.50");
    testing.assertEqual($n.status, "up");
    testing.assertTrue($n.up);
    testing.assertEqual($n.since, "2026-07-24 08:00:01");
    testing.assertEqual($n.interval, "10s");
    testing.assertEqual($n.timeout, "1s");
    testing.assertEqual($n.upScript, ":log info \"printer back\"");
    testing.assertEqual($n.downScript, ":log warning \"printer down\"");
    testing.assertFalse($n.disabled);
    testing.assertEqual($n.comment, "printer");
}

func testNetwatchFromRowDown() {
    def row as map of string to string init {
        ".id": "*2",
        "host": "203.0.113.1",
        "status": "down",
        "since": "2026-07-24 03:12:44"
    };
    def n as NetwatchHost init netwatchFromRow($row);
    testing.assertEqual($n.status, "down");
    testing.assertFalse($n.up);
    testing.assertEqual($n.since, "2026-07-24 03:12:44");
    testing.assertEqual($n.upScript, "");
}

func testNetwatchFromRowUnknownIsNotUp() {
    def row as map of string to string init {".id": "*3", "host": "10.0.0.9", "status": "unknown"};
    def n as NetwatchHost init netwatchFromRow($row);
    testing.assertEqual($n.status, "unknown");
    testing.assertFalse($n.up);
    testing.assertEqual($n.since, "");
}

func testNetwatchFromSparseRow() {
    def row as map of string to string init {".id": "*4", "host": "10.0.0.10"};
    def n as NetwatchHost init netwatchFromRow($row);
    testing.assertEqual($n.status, "");
    testing.assertFalse($n.up);
    testing.assertFalse($n.disabled);
    testing.assertEqual($n.comment, "");
}
