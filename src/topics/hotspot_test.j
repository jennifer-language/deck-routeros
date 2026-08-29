# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the hotspot topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testHotspotFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "guests",
        "interface": "brguest",
        "address-pool": "guests",
        "profile": "guests",
        "disabled": "false"
    };
    def h as HotspotServer init hotspotFromRow($row);
    testing.assertEqual($h.id, "*1");
    testing.assertEqual($h.name, "guests");
    testing.assertEqual($h.interfaceName, "brguest");
    testing.assertEqual($h.addressPool, "guests");
    testing.assertEqual($h.profile, "guests");
    testing.assertFalse($h.disabled);
}

func testHotspotUserFromRow() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "visitor",
        "profile": "default",
        "limit-uptime": "1d",
        "uptime": "3h12m",
        "disabled": "false",
        "comment": "front desk"
    };
    def u as HotspotUser init hotspotUserFromRow($row);
    testing.assertEqual($u.name, "visitor");
    testing.assertEqual($u.profile, "default");
    testing.assertEqual($u.limitUptime, "1d");
    testing.assertEqual($u.uptime, "3h12m");
    testing.assertFalse($u.disabled);
    testing.assertEqual($u.comment, "front desk");
}

func testHotspotUserFromSparseRow() {
    def row as map of string to string init {".id": "*3", "name": "guest"};
    def u as HotspotUser init hotspotUserFromRow($row);
    testing.assertEqual($u.limitUptime, "");
    testing.assertEqual($u.uptime, "");
    testing.assertFalse($u.disabled);
}

func testHotspotSessionFromRow() {
    def row as map of string to string init {
        "user": "visitor",
        "address": "10.5.50.23",
        "mac-address": "AA:BB:CC:DD:EE:FF",
        "uptime": "1h2m",
        "idle-time": "3m",
        "bytes-in": "1048576",
        "bytes-out": "20971520"
    };
    def s as HotspotSession init hotspotSessionFromRow($row);
    testing.assertEqual($s.user, "visitor");
    testing.assertEqual($s.address, "10.5.50.23");
    testing.assertEqual($s.mac, "AA:BB:CC:DD:EE:FF");
    testing.assertEqual($s.uptime, "1h2m");
    testing.assertEqual($s.idleTime, "3m");
    testing.assertEqual($s.bytesIn, 1048576);
    testing.assertEqual($s.bytesOut, 20971520);
}

func testHotspotSessionFromSparseRow() {
    def row as map of string to string init {"user": "visitor", "address": "10.5.50.23"};
    def s as HotspotSession init hotspotSessionFromRow($row);
    testing.assertEqual($s.bytesIn, 0);
    testing.assertEqual($s.bytesOut, 0);
    testing.assertEqual($s.idleTime, "");
}
