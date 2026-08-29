# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the ipsec topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testIpsecPeerFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "tobranch",
        "address": "203.0.113.99",
        "exchange-mode": "ike2",
        "disabled": "false"
    };
    def p as IpsecPeer init ipsecPeerFromRow($row);
    testing.assertEqual($p.id, "*1");
    testing.assertEqual($p.name, "tobranch");
    testing.assertEqual($p.address, "203.0.113.99");
    testing.assertEqual($p.exchangeMode, "ike2");
    testing.assertFalse($p.disabled);
}

func testIpsecPolicyFromRow() {
    def row as map of string to string init {
        ".id": "*2",
        "peer": "tobranch",
        "src-address": "192.168.10.0/24",
        "dst-address": "192.168.20.0/24",
        "tunnel": "true",
        "active": "true",
        "disabled": "false"
    };
    def pol as IpsecPolicy init ipsecPolicyFromRow($row);
    testing.assertEqual($pol.peer, "tobranch");
    testing.assertEqual($pol.srcAddress, "192.168.10.0/24");
    testing.assertEqual($pol.dstAddress, "192.168.20.0/24");
    testing.assertTrue($pol.tunnel);
    testing.assertTrue($pol.active);
}

func testIpsecPolicyFromRowInactive() {
    def row as map of string to string init {".id": "*3", "peer": "tobranch", "tunnel": "true"};
    def pol as IpsecPolicy init ipsecPolicyFromRow($row);
    testing.assertFalse($pol.active);
    testing.assertEqual($pol.srcAddress, "");
}

func testIpsecActiveFromRowEstablished() {
    def row as map of string to string init {
        "remote-address": "203.0.113.99",
        "state": "established",
        "uptime": "2h3m",
        "side": "initiator"
    };
    def a as IpsecActivePeer init ipsecActiveFromRow($row);
    testing.assertEqual($a.remoteAddress, "203.0.113.99");
    testing.assertTrue($a.established);
    testing.assertEqual($a.uptime, "2h3m");
    testing.assertEqual($a.side, "initiator");
}

func testIpsecActiveFromRowNegotiating() {
    def row as map of string to string init {
        "remote-address": "203.0.113.99",
        "state": "negotiating"
    };
    def a as IpsecActivePeer init ipsecActiveFromRow($row);
    testing.assertFalse($a.established);
    testing.assertEqual($a.uptime, "");
}

func testFirstChainRowIdFindsFirstInChain() {
    def rows as list of map of string to string init [
        {".id": "*1", "chain": "dstnat", "action": "dst-nat"},
        {".id": "*2", "chain": "srcnat", "action": "masquerade"},
        {".id": "*3", "chain": "srcnat", "action": "accept"}
    ];
    testing.assertEqual(firstChainRowId($rows, "srcnat"), "*2");
    testing.assertEqual(firstChainRowId($rows, "dstnat"), "*1");
}

func testFirstChainRowIdEmptyChain() {
    def rows as list of map of string to string init [
        {".id": "*1", "chain": "dstnat", "action": "dst-nat"}
    ];
    testing.assertEqual(firstChainRowId($rows, "srcnat"), "");
}

func testIpsecModeConfigPathConstant() {
    testing.assertEqual(IPSEC_MODE_CONFIG_PATH, "/ip/ipsec/mode-config");
}
