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

func testContainerFromRowPrefersCommentOverImageTag() {
    # RouterOS 7.21.5 reports "name" as the image tag, read-only.
    def row as map of string to string init {
        ".id": "*4",
        "name": "pihole:latest",
        "comment": "pihole",
        "interface": "veth-pihole",
        "root-dir": "/usb1-part1/pihole/rootfs",
        "running": "true"
    };
    def ct as Container init containerFromRow($row);
    testing.assertEqual($ct.name, "pihole");
    testing.assertEqual($ct.tag, "pihole:latest");
    testing.assertTrue($ct.running);
    testing.assertEqual($ct.status, "running");
}

func testContainerFromRowRunningFromPlainBool() {
    def row as map of string to string init {".id": "*4", "comment": "pihole", "running": "false"};
    def ct as Container init containerFromRow($row);
    testing.assertFalse($ct.running);
    testing.assertEqual($ct.status, "stopped");
}

func testContainerFromRowTagFallsBackToRemoteImage() {
    def row as map of string to string init {
        ".id": "*5",
        "comment": "adguard",
        "remote-image": "adguard/adguardhome:latest"
    };
    def ct as Container init containerFromRow($row);
    testing.assertEqual($ct.tag, "adguard/adguardhome:latest");
    testing.assertEqual($ct.name, "adguard");
}

func testContainerFromRowCarriesLists() {
    def row as map of string to string init {
        ".id": "*4",
        "comment": "pihole",
        "envlists": "pihole-env",
        "mountlists": "pihole-etc,pihole-dnsmasq"
    };
    def ct as Container init containerFromRow($row);
    testing.assertEqual($ct.envLists, "pihole-env");
    testing.assertEqual($ct.mountLists, "pihole-etc,pihole-dnsmasq");
}

func testContainerEnvFromRow() {
    def row as map of string to string init {".id": "*1", "list": "pihole-env", "key": "TZ", "value": "Europe/Vienna"};
    def e as ContainerEnv init containerEnvFromRow($row);
    testing.assertEqual($e.listName, "pihole-env");
    testing.assertEqual($e.key, "TZ");
    testing.assertEqual($e.value, "Europe/Vienna");
}

func testContainerMountFromRow() {
    def row as map of string to string init {".id": "*2", "list": "pihole-etc", "src": "usb1/pihole/etc", "dst": "/etc/pihole"};
    def m as ContainerMount init containerMountFromRow($row);
    testing.assertEqual($m.listName, "pihole-etc");
    testing.assertEqual($m.src, "usb1/pihole/etc");
    testing.assertEqual($m.dst, "/etc/pihole");
}

func testJoinListNames() {
    testing.assertEqual(joinListNames(["a", "b"], "env list"), "a,b");
    def none as list of string init [];
    testing.assertEqual(joinListNames($none, "env list"), "");
}

func failJoinListNamesEmptyEntry() {
    joinListNames(["ok", ""], "env list");
}

func testJoinListNamesRejectsEmptyEntry() {
    testing.assertThrows("failJoinListNamesEmptyEntry", "routeros");
}
