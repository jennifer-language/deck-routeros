# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the contrack topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testConntrackFromRow() {
    def row as map of string to string init {
        "enabled": "yes",
        "total-entries": "1234",
        "max-entries": "131072"
    };
    def s as ConntrackSettings init conntrackFromRow($row);
    testing.assertEqual($s.enabled, "yes");
    testing.assertEqual($s.totalEntries, 1234);
    testing.assertEqual($s.maxEntries, 131072);
}

func testConnectionFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "protocol": "tcp",
        "src-address": "192.168.88.10:51000",
        "dst-address": "93.184.216.34:443",
        "tcp-state": "established",
        "timeout": "23h59m",
        "connection-mark": "voip-conn"
    };
    def con as Connection init connectionFromRow($row);
    testing.assertEqual($con.protocol, "tcp");
    testing.assertEqual($con.srcAddress, "192.168.88.10:51000");
    testing.assertEqual($con.dstAddress, "93.184.216.34:443");
    testing.assertEqual($con.tcpState, "established");
    testing.assertEqual($con.connectionMark, "voip-conn");
}

func testConnectionFromSparseRow() {
    def row as map of string to string init {".id": "*2", "protocol": "udp"};
    def con as Connection init connectionFromRow($row);
    testing.assertEqual($con.tcpState, "");
    testing.assertEqual($con.connectionMark, "");
}
