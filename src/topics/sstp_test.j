# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the sstp topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testSstpServerFromRow() {
    def row as map of string to string init {
        "enabled": "true",
        "port": "443",
        "certificate": "router-le-cert",
        "default-profile": "default"
    };
    def s as SstpServer init sstpServerFromRow($row);
    testing.assertTrue($s.enabled);
    testing.assertEqual($s.port, 443);
    testing.assertEqual($s.certificate, "router-le-cert");
    testing.assertEqual($s.defaultProfile, "default");
}

func testSstpClientFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "sstpto-hq",
        "connect-to": "vpn.example.org",
        "user": "branch",
        "running": "false"
    };
    def cl as SstpClient init sstpClientFromRow($row);
    testing.assertEqual($cl.name, "sstpto-hq");
    testing.assertEqual($cl.connectTo, "vpn.example.org");
    testing.assertFalse($cl.running);
    testing.assertEqual($cl.comment, "");
}
