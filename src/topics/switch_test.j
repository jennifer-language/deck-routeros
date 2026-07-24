# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the switch topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testSwitchChipFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "switch1",
        "type": "Atheros-8327"
    };
    def sw as SwitchChip init switchChipFromRow($row);
    testing.assertEqual($sw.id, "*1");
    testing.assertEqual($sw.name, "switch1");
    testing.assertEqual($sw.kind, "Atheros-8327");
}

func testSwitchHostFromRow() {
    def row as map of string to string init {
        "mac-address": "AA:BB:CC:DD:EE:FF",
        "ports": "ether3",
        "vlan-id": "10",
        "dynamic": "true"
    };
    def h as SwitchHost init switchHostFromRow($row);
    testing.assertEqual($h.mac, "AA:BB:CC:DD:EE:FF");
    testing.assertEqual($h.ports, "ether3");
    testing.assertEqual($h.vlanId, 10);
    testing.assertTrue($h.dynamic);
}

func testSwitchHostFromSparseRow() {
    def row as map of string to string init {"mac-address": "11:22:33:44:55:66", "ports": "ether1"};
    def h as SwitchHost init switchHostFromRow($row);
    testing.assertEqual($h.vlanId, 0);
    testing.assertFalse($h.dynamic);
}
