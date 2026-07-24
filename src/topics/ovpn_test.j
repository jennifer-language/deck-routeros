# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the ovpn topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testOvpnServerFromRow() {
    def row as map of string to string init {
        "enabled": "true",
        "port": "1194",
        "mode": "ip",
        "certificate": "router-le-cert",
        "default-profile": "default"
    };
    def s as OvpnServer init ovpnServerFromRow($row);
    testing.assertTrue($s.enabled);
    testing.assertEqual($s.port, 1194);
    testing.assertEqual($s.mode, "ip");
    testing.assertEqual($s.certificate, "router-le-cert");
}

func testOvpnClientFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "ovpnto-hq",
        "connect-to": "vpn.example.org",
        "user": "branch",
        "running": "true",
        "comment": "to HQ"
    };
    def cl as OvpnClient init ovpnClientFromRow($row);
    testing.assertEqual($cl.name, "ovpnto-hq");
    testing.assertEqual($cl.user, "branch");
    testing.assertTrue($cl.running);
    testing.assertEqual($cl.comment, "to HQ");
}
