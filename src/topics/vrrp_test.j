# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the vrrp topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testVrrpFromRowMaster() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "vrrplan",
        "interface": "brlan",
        "vrid": "10",
        "priority": "200",
        "interval": "1s",
        "version": "3",
        "preemption-mode": "true",
        "running": "true",
        "backup": "false",
        "disabled": "false",
        "comment": "gateway pair"
    };
    def v as VrrpInterface init vrrpFromRow($row);
    testing.assertEqual($v.id, "*1");
    testing.assertEqual($v.name, "vrrplan");
    testing.assertEqual($v.interfaceName, "brlan");
    testing.assertEqual($v.vrid, 10);
    testing.assertEqual($v.priority, 200);
    testing.assertEqual($v.interval, "1s");
    testing.assertEqual($v.version, 3);
    testing.assertTrue($v.preemption);
    testing.assertTrue($v.running);
    testing.assertFalse($v.backup);
    testing.assertTrue($v.master);
    testing.assertEqual($v.comment, "gateway pair");
}

func testVrrpFromRowBackup() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "vrrplan",
        "interface": "brlan",
        "vrid": "10",
        "priority": "100",
        "running": "true",
        "backup": "true"
    };
    def v as VrrpInterface init vrrpFromRow($row);
    testing.assertTrue($v.running);
    testing.assertTrue($v.backup);
    testing.assertFalse($v.master);
}

func testVrrpFromRowDownIsNotMaster() {
    def row as map of string to string init {
        ".id": "*3",
        "name": "vrrplan",
        "interface": "brlan",
        "vrid": "10",
        "running": "false"
    };
    def v as VrrpInterface init vrrpFromRow($row);
    testing.assertFalse($v.running);
    testing.assertFalse($v.master);
    testing.assertEqual($v.priority, 0);
}

func testEnsureVridAcceptsBounds() {
    ensureVrid(1);
    ensureVrid(10);
    ensureVrid(255);
    testing.assertTrue(true);
}

func failVridZero() {
    ensureVrid(0);
}

func testEnsureVridRejectsZero() {
    testing.assertThrows("failVridZero", "routeros");
}

func failVridTooBig() {
    ensureVrid(256);
}

func testEnsureVridRejectsTooBig() {
    testing.assertThrows("failVridTooBig", "routeros");
}

func testEnsureVrrpPriorityAcceptsBounds() {
    ensureVrrpPriority(1);
    ensureVrrpPriority(200);
    ensureVrrpPriority(254);
    testing.assertTrue(true);
}

func failVrrpPriorityZero() {
    ensureVrrpPriority(0);
}

func testEnsureVrrpPriorityRejectsZero() {
    testing.assertThrows("failVrrpPriorityZero", "routeros");
}

func failVrrpPriorityOwner() {
    ensureVrrpPriority(255);
}

func testEnsureVrrpPriorityRejectsOwnerValue() {
    testing.assertThrows("failVrrpPriorityOwner", "routeros");
}

func testFindVrrpRowMatchesInterfaceAndVrid() {
    def rows as list of map of string to string init [
        {".id": "*1", "name": "vrrplan", "interface": "brlan", "vrid": "10"},
        {".id": "*2", "name": "vrrpdmz", "interface": "brdmz", "vrid": "10"}
    ];
    def row as map of string to string init findVrrpRow($rows, "brdmz", 10);
    testing.assertEqual(rowValue($row, "name"), "vrrpdmz");
}

func testFindVrrpRowSameVridOtherInterfaceIsFree() {
    def rows as list of map of string to string init [
        {".id": "*1", "name": "vrrplan", "interface": "brlan", "vrid": "10"}
    ];
    def row as map of string to string init findVrrpRow($rows, "brguest", 10);
    testing.assertEqual(len($row), 0);
}
