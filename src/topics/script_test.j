# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the script topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testScriptFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "nightly-backup",
        "source": "/system backup save name=nightly",
        "policy": "ftp,reboot,read,write,policy,test",
        "run-count": "17",
        "last-started": "2026-07-24 03:00:01",
        "comment": "keep a backup"
    };
    def s as Script init scriptFromRow($row);
    testing.assertEqual($s.id, "*1");
    testing.assertEqual($s.name, "nightly-backup");
    testing.assertEqual($s.source, "/system backup save name=nightly");
    testing.assertEqual($s.policy, "ftp,reboot,read,write,policy,test");
    testing.assertEqual($s.runCount, 17);
    testing.assertEqual($s.lastStarted, "2026-07-24 03:00:01");
    testing.assertEqual($s.comment, "keep a backup");
}

func testScriptFromSparseRow() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "hello",
        "source": ":log info hello"
    };
    def s as Script init scriptFromRow($row);
    testing.assertEqual($s.runCount, 0);
    testing.assertEqual($s.lastStarted, "");
    testing.assertEqual($s.comment, "");
}
