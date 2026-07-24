# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the ip topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testIpAddressFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "address": "192.168.88.1/24",
        "network": "192.168.88.0",
        "interface": "brlan",
        "dynamic": "false",
        "disabled": "false",
        "comment": "lan gateway"
    };
    def a as IpAddress init ipAddressFromRow($row);
    testing.assertEqual($a.id, "*1");
    testing.assertEqual($a.address, "192.168.88.1/24");
    testing.assertEqual($a.network, "192.168.88.0");
    testing.assertEqual($a.interfaceName, "brlan");
    testing.assertFalse($a.dynamic);
    testing.assertFalse($a.disabled);
    testing.assertEqual($a.comment, "lan gateway");
}
