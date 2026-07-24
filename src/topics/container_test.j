# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the container topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testContainerFromRowRunning() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "pihole",
        "tag": "pihole/pihole:latest",
        "status": "running",
        "interface": "veth1",
        "root-dir": "usb1/pihole"
    };
    def ct as Container init containerFromRow($row);
    testing.assertEqual($ct.name, "pihole");
    testing.assertEqual($ct.tag, "pihole/pihole:latest");
    testing.assertEqual($ct.status, "running");
    testing.assertTrue($ct.running);
    testing.assertEqual($ct.interfaceName, "veth1");
    testing.assertEqual($ct.rootDir, "usb1/pihole");
}

func testContainerFromRowStoppedNamedByComment() {
    def row as map of string to string init {
        ".id": "*2",
        "comment": "adguard",
        "status": "stopped",
        "tag": "adguard/adguardhome:latest"
    };
    def ct as Container init containerFromRow($row);
    testing.assertEqual($ct.name, "adguard");
    testing.assertFalse($ct.running);
    testing.assertEqual($ct.status, "stopped");
}
