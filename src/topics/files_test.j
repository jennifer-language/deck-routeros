# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the files topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testFileFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "nightly.backup",
        "type": "backup",
        "size": "182348",
        "creation-time": "2026-07-24 03:30:01"
    };
    def f as RouterFile init fileFromRow($row);
    testing.assertEqual($f.name, "nightly.backup");
    testing.assertEqual($f.kind, "backup");
    testing.assertEqual($f.size, 182348);
    testing.assertEqual($f.creationTime, "2026-07-24 03:30:01");
}

func testFileFromSparseRow() {
    def row as map of string to string init {".id": "*2", "name": "flash", "type": "directory"};
    def f as RouterFile init fileFromRow($row);
    testing.assertEqual($f.kind, "directory");
    testing.assertEqual($f.size, 0);
    testing.assertEqual($f.creationTime, "");
}
