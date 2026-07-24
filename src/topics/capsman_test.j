# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the capsman topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testManagedApFromRow() {
    def row as map of string to string init {
        "identity": "ap-lobby",
        "address": "10.0.9.31",
        "interface": "cap1",
        "state": "running"
    };
    def ap as ManagedAp init managedApFromRow($row);
    testing.assertEqual($ap.identity, "ap-lobby");
    testing.assertEqual($ap.address, "10.0.9.31");
    testing.assertEqual($ap.interfaceName, "cap1");
    testing.assertEqual($ap.state, "running");
}

func testManagedApFromSparseRow() {
    def row as map of string to string init {"identity": "ap-2"};
    def ap as ManagedAp init managedApFromRow($row);
    testing.assertEqual($ap.address, "");
    testing.assertEqual($ap.state, "");
}
