# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the vlans topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testEnsureVlanIdAcceptsBounds() {
    ensureVlanId(1);
    ensureVlanId(4094);
    ensureVlanId(20);
    testing.assertTrue(true);
}

func failEnsureVlanIdZero() {
    ensureVlanId(0);
}

func testEnsureVlanIdRejectsZero() {
    testing.assertThrows("failEnsureVlanIdZero", "routeros");
}

func failEnsureVlanIdTooBig() {
    ensureVlanId(4095);
}

func testEnsureVlanIdRejectsTooBig() {
    testing.assertThrows("failEnsureVlanIdTooBig", "routeros");
}

func testVlanFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "vlanoffice",
        "vlan-id": "20",
        "interface": "ether2",
        "mtu": "1500",
        "running": "true",
        "disabled": "false",
        "comment": "office network"
    };
    def v as Vlan init vlanFromRow($row);
    testing.assertEqual($v.id, "*1");
    testing.assertEqual($v.name, "vlanoffice");
    testing.assertEqual($v.vlanId, 20);
    testing.assertEqual($v.interfaceName, "ether2");
    testing.assertEqual($v.mtu, "1500");
    testing.assertTrue($v.running);
    testing.assertFalse($v.disabled);
    testing.assertEqual($v.comment, "office network");
}

func testVlanFromSparseRow() {
    def row as map of string to string init {".id": "*2", "name": "vlantest", "vlan-id": "42"};
    def v as Vlan init vlanFromRow($row);
    testing.assertEqual($v.vlanId, 42);
    testing.assertEqual($v.interfaceName, "");
    testing.assertFalse($v.running);
    testing.assertEqual($v.comment, "");
}
