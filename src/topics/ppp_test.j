# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the ppp topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testPppoeFromRowConnected() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "pppoewan",
        "interface": "ether1",
        "user": "user@provider.example",
        "use-peer-dns": "true",
        "add-default-route": "true",
        "running": "true",
        "disabled": "false",
        "comment": "dsl uplink"
    };
    def p as PppoeClient init pppoeFromRow($row);
    testing.assertEqual($p.id, "*1");
    testing.assertEqual($p.name, "pppoewan");
    testing.assertEqual($p.interfaceName, "ether1");
    testing.assertEqual($p.user, "user@provider.example");
    testing.assertTrue($p.usePeerDns);
    testing.assertTrue($p.addDefaultRoute);
    testing.assertTrue($p.running);
    testing.assertFalse($p.disabled);
    testing.assertEqual($p.comment, "dsl uplink");
}

func testPppoeFromRowDown() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "pppoewan",
        "interface": "ether1",
        "user": "user@provider.example",
        "running": "false"
    };
    def p as PppoeClient init pppoeFromRow($row);
    testing.assertFalse($p.running);
    testing.assertFalse($p.usePeerDns);
    testing.assertEqual($p.comment, "");
}

func testEnsurePppServiceAcceptsKnown() {
    ensurePppService("any");
    ensurePppService("l2tp");
    ensurePppService("sstp");
    ensurePppService("ovpn");
    testing.assertTrue(true);
}

func failPppServiceUnknown() {
    ensurePppService("magic");
}

func testEnsurePppServiceRejectsUnknown() {
    testing.assertThrows("failPppServiceUnknown", "routeros");
}

func testPppUserFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "alice",
        "service": "any",
        "profile": "default",
        "remote-address": "10.50.0.5",
        "disabled": "false",
        "comment": "field laptop"
    };
    def u as PppUser init pppUserFromRow($row);
    testing.assertEqual($u.name, "alice");
    testing.assertEqual($u.service, "any");
    testing.assertEqual($u.profile, "default");
    testing.assertEqual($u.remoteAddress, "10.50.0.5");
    testing.assertEqual($u.comment, "field laptop");
}

func testPppProfileFromRow() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "vpn-profile",
        "local-address": "10.50.0.1",
        "remote-address": "vpn-pool",
        "dns-server": "10.50.0.1"
    };
    def p as PppProfile init pppProfileFromRow($row);
    testing.assertEqual($p.name, "vpn-profile");
    testing.assertEqual($p.localAddress, "10.50.0.1");
    testing.assertEqual($p.remoteAddress, "vpn-pool");
    testing.assertEqual($p.dnsServer, "10.50.0.1");
}

func testPppSessionFromRow() {
    def row as map of string to string init {
        "name": "alice",
        "service": "l2tp",
        "address": "10.50.0.5",
        "uptime": "1h2m",
        "caller-id": "203.0.113.7"
    };
    def s as PppSession init pppSessionFromRow($row);
    testing.assertEqual($s.name, "alice");
    testing.assertEqual($s.service, "l2tp");
    testing.assertEqual($s.address, "10.50.0.5");
    testing.assertEqual($s.callerId, "203.0.113.7");
}

func testPppoeServerFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "service-name": "office",
        "interface": "ether2",
        "default-profile": "default",
        "disabled": "false"
    };
    def s as PppoeServer init pppoeServerFromRow($row);
    testing.assertEqual($s.serviceName, "office");
    testing.assertEqual($s.interfaceName, "ether2");
    testing.assertEqual($s.defaultProfile, "default");
    testing.assertFalse($s.disabled);
}
