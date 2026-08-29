# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the bonding topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testBondFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "bondtrunk",
        "slaves": "ether1,ether2",
        "mode": "802.3ad",
        "transmit-hash-policy": "layer-2-and-3",
        "mac-address": "AA:BB:CC:DD:EE:01",
        "mtu": "1500",
        "running": "true",
        "disabled": "false",
        "comment": "to core switch"
    };
    def b as Bond init bondFromRow($row);
    testing.assertEqual($b.id, "*1");
    testing.assertEqual($b.name, "bondtrunk");
    testing.assertEqual($b.slaves, "ether1,ether2");
    testing.assertEqual($b.mode, "802.3ad");
    testing.assertEqual($b.primary, "");
    testing.assertEqual($b.transmitHashPolicy, "layer-2-and-3");
    testing.assertEqual($b.mac, "AA:BB:CC:DD:EE:01");
    testing.assertTrue($b.running);
    testing.assertFalse($b.disabled);
    testing.assertEqual($b.comment, "to core switch");
}

func testBondFromRowFailover() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "bonduplink",
        "slaves": "ether1,ether2",
        "mode": "active-backup",
        "primary": "ether1",
        "running": "false"
    };
    def b as Bond init bondFromRow($row);
    testing.assertEqual($b.mode, "active-backup");
    testing.assertEqual($b.primary, "ether1");
    testing.assertFalse($b.running);
    testing.assertEqual($b.transmitHashPolicy, "");
}

func testEnsureBondModeAcceptsKnown() {
    ensureBondMode("802.3ad");
    ensureBondMode("active-backup");
    ensureBondMode("balance-rr");
    testing.assertTrue(true);
}

func failBondModeUnknown() {
    ensureBondMode("round-robin");
}

func testEnsureBondModeRejectsUnknown() {
    testing.assertThrows("failBondModeUnknown", "routeros");
}

func testNormalizedSlavesForms() {
    testing.assertEqual(normalizedSlaves("ether1,ether2"), "ether1,ether2");
    testing.assertEqual(normalizedSlaves(" ether1 , ether2 , ether3 "), "ether1,ether2,ether3");
}

func failSlavesSingleMember() {
    normalizedSlaves("ether1");
}

func testNormalizedSlavesRejectsSingleMember() {
    testing.assertThrows("failSlavesSingleMember", "routeros");
}

func failSlavesDuplicate() {
    normalizedSlaves("ether1,ether2,ether1");
}

func testNormalizedSlavesRejectsDuplicate() {
    testing.assertThrows("failSlavesDuplicate", "routeros");
}

func failSlavesEmptyEntry() {
    normalizedSlaves("ether1,,ether2");
}

func testNormalizedSlavesRejectsEmptyEntry() {
    testing.assertThrows("failSlavesEmptyEntry", "routeros");
}

func failSlavesSpacedName() {
    normalizedSlaves("ether1,ether 2");
}

func testNormalizedSlavesRejectsSpacedName() {
    testing.assertThrows("failSlavesSpacedName", "routeros");
}

func testBondHasSlave() {
    testing.assertTrue(bondHasSlave("ether1,ether2", "ether2"));
    testing.assertTrue(bondHasSlave("ether1, ether2", "ether2"));
    testing.assertFalse(bondHasSlave("ether1,ether2", "ether3"));
    testing.assertFalse(bondHasSlave("ether10", "ether1"));
    testing.assertFalse(bondHasSlave("", "ether1"));
}

func testBondUsingSlaveFindsOwner() {
    def rows as list of map of string to string init [
        {"name": "bonda", "slaves": "ether1,ether2"},
        {"name": "bondb", "slaves": "ether3,ether4"}
    ];
    testing.assertEqual(bondUsingSlave($rows, "ether3"), "bondb");
    testing.assertEqual(bondUsingSlave($rows, "ether5"), "");
}

func testEnsurePrimaryInSlavesAcceptsMember() {
    ensurePrimaryInSlaves("ether1,ether2", "ether1");
    testing.assertTrue(true);
}

func failPrimaryNotMember() {
    ensurePrimaryInSlaves("ether1,ether2", "ether3");
}

func testEnsurePrimaryInSlavesRejectsOutsider() {
    testing.assertThrows("failPrimaryNotMember", "routeros");
}
