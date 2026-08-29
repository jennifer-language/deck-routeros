# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the wireguard topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testEnsureWireguardKeyAcceptsValidKey() {
    ensureWireguardKey("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopq=");
    ensureWireguardKey("  hIe5R2FTPjvrIrVXfy41chvUJ4CyOTdBEI3pQGea0R0=  ");
    testing.assertTrue(true);
}

func failWireguardKeyTooShort() {
    ensureWireguardKey("ABCDEF=");
}

func testEnsureWireguardKeyRejectsTooShort() {
    testing.assertThrows("failWireguardKeyTooShort", "routeros");
}

func failWireguardKeyNoPadding() {
    ensureWireguardKey("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqA");
}

func testEnsureWireguardKeyRejectsMissingPadding() {
    testing.assertThrows("failWireguardKeyNoPadding", "routeros");
}

func failWireguardKeyBadCharacter() {
    ensureWireguardKey("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnop!=");
}

func testEnsureWireguardKeyRejectsBadCharacter() {
    testing.assertThrows("failWireguardKeyBadCharacter", "routeros");
}

func testNormalizedAllowedAddressForms() {
    testing.assertEqual(normalizedAllowedAddress("10.100.0.2/32"), "10.100.0.2/32");
    testing.assertEqual(
        normalizedAllowedAddress(" 10.100.0.0/24 , 192.168.88.0/24 "),
        "10.100.0.0/24,192.168.88.0/24");
    testing.assertEqual(normalizedAllowedAddress("0.0.0.0/0"), "0.0.0.0/0");
}

func failAllowedAddressBareIp() {
    normalizedAllowedAddress("10.100.0.2");
}

func testNormalizedAllowedAddressRejectsBareIp() {
    testing.assertThrows("failAllowedAddressBareIp", "routeros");
}

func failAllowedAddressEmptyEntry() {
    normalizedAllowedAddress("10.100.0.2/32,,10.100.0.3/32");
}

func testNormalizedAllowedAddressRejectsEmptyEntry() {
    testing.assertThrows("failAllowedAddressEmptyEntry", "routeros");
}

func testWireguardFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "wgvpn",
        "public-key": "hIe5R2FTPjvrIrVXfy41chvUJ4CyOTdBEI3pQGea0R0=",
        "listen-port": "13231",
        "mtu": "1420",
        "running": "true",
        "disabled": "false",
        "comment": "road warriors"
    };
    def w as WireguardInterface init wireguardFromRow($row);
    testing.assertEqual($w.id, "*1");
    testing.assertEqual($w.name, "wgvpn");
    testing.assertEqual($w.publicKey, "hIe5R2FTPjvrIrVXfy41chvUJ4CyOTdBEI3pQGea0R0=");
    testing.assertEqual($w.listenPort, 13231);
    testing.assertEqual($w.mtu, "1420");
    testing.assertTrue($w.running);
    testing.assertFalse($w.disabled);
    testing.assertEqual($w.comment, "road warriors");
}

func testWireguardPeerFromRowDialIn() {
    def row as map of string to string init {
        ".id": "*2",
        "interface": "wgvpn",
        "public-key": "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopq=",
        "allowed-address": "10.100.0.2/32",
        "last-handshake": "1m2s",
        "rx": "1048576",
        "tx": "2097152",
        "disabled": "false",
        "comment": "laptop"
    };
    def p as WireguardPeer init wireguardPeerFromRow($row);
    testing.assertEqual($p.interfaceName, "wgvpn");
    testing.assertEqual($p.publicKey, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopq=");
    testing.assertEqual($p.endpointAddress, "");
    testing.assertEqual($p.allowedAddress, "10.100.0.2/32");
    testing.assertEqual($p.lastHandshake, "1m2s");
    testing.assertEqual($p.rx, "1048576");
    testing.assertEqual($p.tx, "2097152");
    testing.assertEqual($p.comment, "laptop");
}

func testWireguardPeerFromRowDialOut() {
    def row as map of string to string init {
        ".id": "*3",
        "interface": "wghome",
        "public-key": "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopq=",
        "endpoint-address": "vpn.example.org",
        "endpoint-port": "13231",
        "allowed-address": "10.100.0.0/24",
        "persistent-keepalive": "25s"
    };
    def p as WireguardPeer init wireguardPeerFromRow($row);
    testing.assertEqual($p.endpointAddress, "vpn.example.org");
    testing.assertEqual($p.endpointPort, "13231");
    testing.assertEqual($p.keepalive, "25s");
    testing.assertEqual($p.lastHandshake, "");
    testing.assertFalse($p.disabled);
}
