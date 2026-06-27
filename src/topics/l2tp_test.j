# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the l2tp topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testL2tpServerFromRowEnabled() {
    def row as map of string to string init {
        "enabled": "true",
        "use-ipsec": "required",
        "default-profile": "default-encryption"
    };
    def s as L2tpServer init l2tpServerFromRow($row);
    testing.assertTrue($s.enabled);
    testing.assertTrue($s.useIpsec);
    testing.assertEqual($s.defaultProfile, "default-encryption");
}

func testL2tpServerFromRowNoIpsec() {
    def row as map of string to string init {"enabled": "false", "use-ipsec": "no"};
    def s as L2tpServer init l2tpServerFromRow($row);
    testing.assertFalse($s.enabled);
    testing.assertFalse($s.useIpsec);
}

func testL2tpClientFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "l2tpto-hq",
        "connect-to": "vpn.example.org",
        "user": "branch",
        "running": "true",
        "disabled": "false",
        "comment": "to HQ"
    };
    def cl as L2tpClient init l2tpClientFromRow($row);
    testing.assertEqual($cl.name, "l2tpto-hq");
    testing.assertEqual($cl.connectTo, "vpn.example.org");
    testing.assertEqual($cl.user, "branch");
    testing.assertTrue($cl.running);
    testing.assertEqual($cl.comment, "to HQ");
}
