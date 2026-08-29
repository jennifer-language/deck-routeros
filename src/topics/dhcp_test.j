# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the dhcp topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testDhcpServerFromRow() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "dhcplan",
        "interface": "brlan",
        "address-pool": "dhcplan",
        "lease-time": "30m",
        "disabled": "false"
    };
    def s as DhcpServer init dhcpServerFromRow($row);
    testing.assertEqual($s.id, "*2");
    testing.assertEqual($s.name, "dhcplan");
    testing.assertEqual($s.interfaceName, "brlan");
    testing.assertEqual($s.addressPool, "dhcplan");
    testing.assertEqual($s.leaseTime, "30m");
    testing.assertFalse($s.disabled);
}

func testDhcpLeaseFromRowDynamic() {
    def row as map of string to string init {
        ".id": "*3",
        "address": "192.168.88.42",
        "mac-address": "AA:BB:CC:DD:EE:FF",
        "host-name": "laptop",
        "server": "dhcplan",
        "status": "bound",
        "dynamic": "true",
        "expires-after": "23m11s"
    };
    def l as DhcpLease init dhcpLeaseFromRow($row);
    testing.assertEqual($l.address, "192.168.88.42");
    testing.assertEqual($l.mac, "AA:BB:CC:DD:EE:FF");
    testing.assertEqual($l.hostName, "laptop");
    testing.assertEqual($l.server, "dhcplan");
    testing.assertEqual($l.status, "bound");
    testing.assertTrue($l.dynamic);
    testing.assertEqual($l.expiresAfter, "23m11s");
    testing.assertEqual($l.comment, "");
}

func testDhcpLeaseFromRowStaticReservation() {
    def row as map of string to string init {
        ".id": "*4",
        "address": "192.168.88.50",
        "mac-address": "AA:BB:CC:00:11:22",
        "dynamic": "false",
        "comment": "printer"
    };
    def l as DhcpLease init dhcpLeaseFromRow($row);
    testing.assertFalse($l.dynamic);
    testing.assertEqual($l.expiresAfter, "");
    testing.assertEqual($l.comment, "printer");
}

func testDhcpClientFromRowBound() {
    def row as map of string to string init {
        ".id": "*1",
        "interface": "ether1",
        "status": "bound",
        "address": "203.0.113.5/24",
        "gateway": "203.0.113.1",
        "primary-dns": "203.0.113.53",
        "secondary-dns": "203.0.113.54",
        "expires-after": "23h59m",
        "use-peer-dns": "true",
        "add-default-route": "yes",
        "disabled": "false",
        "comment": "isp uplink"
    };
    def w as DhcpClient init dhcpClientFromRow($row);
    testing.assertEqual($w.id, "*1");
    testing.assertEqual($w.interfaceName, "ether1");
    testing.assertEqual($w.status, "bound");
    testing.assertTrue($w.bound);
    testing.assertEqual($w.address, "203.0.113.5/24");
    testing.assertEqual($w.gateway, "203.0.113.1");
    testing.assertEqual($w.primaryDns, "203.0.113.53");
    testing.assertEqual($w.secondaryDns, "203.0.113.54");
    testing.assertEqual($w.expiresAfter, "23h59m");
    testing.assertTrue($w.usePeerDns);
    testing.assertEqual($w.addDefaultRoute, "yes");
    testing.assertFalse($w.disabled);
    testing.assertEqual($w.comment, "isp uplink");
}

func testDhcpClientFromRowSearching() {
    def row as map of string to string init {
        ".id": "*2",
        "interface": "ether1",
        "status": "searching..."
    };
    def w as DhcpClient init dhcpClientFromRow($row);
    testing.assertEqual($w.status, "searching...");
    testing.assertFalse($w.bound);
    testing.assertEqual($w.address, "");
    testing.assertEqual($w.gateway, "");
}

func testDhcpClientFromRowKeepsSpecialRoute() {
    def row as map of string to string init {
        ".id": "*3",
        "interface": "ether2",
        "status": "bound",
        "add-default-route": "special-classless",
        "use-peer-dns": "false"
    };
    def w as DhcpClient init dhcpClientFromRow($row);
    testing.assertEqual($w.addDefaultRoute, "special-classless");
    testing.assertFalse($w.usePeerDns);
}

func testDhcpRelayFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "vlan20-relay",
        "interface": "vlanoffice",
        "dhcp-server": "10.0.0.5",
        "disabled": "false"
    };
    def r as DhcpRelay init dhcpRelayFromRow($row);
    testing.assertEqual($r.name, "vlan20-relay");
    testing.assertEqual($r.interfaceName, "vlanoffice");
    testing.assertEqual($r.dhcpServer, "10.0.0.5");
    testing.assertFalse($r.disabled);
}
