# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the nat topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testEnsureForwardProtocolAcceptsTcpUdp() {
    ensureForwardProtocol("tcp");
    ensureForwardProtocol("udp");
    testing.assertTrue(true);
}

func failEnsureForwardProtocolIcmp() {
    ensureForwardProtocol("icmp");
}

func testEnsureForwardProtocolRejectsIcmp() {
    testing.assertThrows("failEnsureForwardProtocolIcmp", "routeros");
}

func failEnsureForwardProtocolEmpty() {
    ensureForwardProtocol("");
}

func testEnsureForwardProtocolRejectsEmpty() {
    testing.assertThrows("failEnsureForwardProtocolEmpty", "routeros");
}

func testFindMasqueradeRowMatches() {
    def rows as list of map of string to string init [
        {".id": "*1", "chain": "dstnat", "action": "dst-nat", "dst-port": "8080"},
        {".id": "*2", "chain": "srcnat", "action": "masquerade", "out-interface": "ether1"}
    ];
    def row as map of string to string init findMasqueradeRow($rows, "ether1");
    testing.assertEqual(rowValue($row, ".id"), "*2");
}

func testFindMasqueradeRowWrongInterfaceIsMiss() {
    def rows as list of map of string to string init [
        {".id": "*1", "chain": "srcnat", "action": "masquerade", "out-interface": "ether2"}
    ];
    def row as map of string to string init findMasqueradeRow($rows, "ether1");
    testing.assertEqual(len($row), 0);
}

func testFindMasqueradeRowIgnoresOtherSrcnatActions() {
    def rows as list of map of string to string init [
        {".id": "*1", "chain": "srcnat", "action": "src-nat", "out-interface": "ether1"}
    ];
    def row as map of string to string init findMasqueradeRow($rows, "ether1");
    testing.assertEqual(len($row), 0);
}

func testFindMasqueradeRowEmptyRows() {
    def rows as list of map of string to string init [];
    def row as map of string to string init findMasqueradeRow($rows, "ether1");
    testing.assertEqual(len($row), 0);
}

func testNatFromRowPortForward() {
    def row as map of string to string init {
        ".id": "*A",
        "chain": "dstnat",
        "action": "dst-nat",
        "protocol": "tcp",
        "dst-port": "8080",
        "to-addresses": "192.168.88.10",
        "to-ports": "80",
        "in-interface": "ether1",
        "comment": "web server",
        "disabled": "false"
    };
    def n as NatRule init natFromRow($row);
    testing.assertEqual($n.id, "*A");
    testing.assertEqual($n.chain, "dstnat");
    testing.assertEqual($n.action, "dst-nat");
    testing.assertEqual($n.protocol, "tcp");
    testing.assertEqual($n.dstPort, "8080");
    testing.assertEqual($n.toAddresses, "192.168.88.10");
    testing.assertEqual($n.toPorts, "80");
    testing.assertEqual($n.inInterface, "ether1");
    testing.assertEqual($n.outInterface, "");
    testing.assertEqual($n.comment, "web server");
    testing.assertFalse($n.disabled);
}

func testNatFromRowMasquerade() {
    def row as map of string to string init {
        ".id": "*B",
        "chain": "srcnat",
        "action": "masquerade",
        "out-interface": "ether1"
    };
    def n as NatRule init natFromRow($row);
    testing.assertEqual($n.chain, "srcnat");
    testing.assertEqual($n.action, "masquerade");
    testing.assertEqual($n.outInterface, "ether1");
    testing.assertEqual($n.toAddresses, "");
    testing.assertEqual($n.dstPort, "");
    testing.assertFalse($n.disabled);
}
