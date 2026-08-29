# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the wifi (wave2) topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testWifiFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "wifi1",
        "configuration.ssid": "My Home WiFi",
        "channel.band": "5ghz-ax",
        "running": "true",
        "disabled": "false",
        "comment": "living room"
    };
    def w as WifiInterface init wifiFromRow($row);
    testing.assertEqual($w.id, "*1");
    testing.assertEqual($w.name, "wifi1");
    testing.assertEqual($w.ssid, "My Home WiFi");
    testing.assertEqual($w.band, "5ghz-ax");
    testing.assertEqual($w.masterInterface, "");
    testing.assertTrue($w.running);
    testing.assertFalse($w.disabled);
    testing.assertEqual($w.comment, "living room");
}

func testWifiFromRowVirtualAp() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "wifiguest",
        "configuration.ssid": "Guest",
        "master-interface": "wifi1"
    };
    def w as WifiInterface init wifiFromRow($row);
    testing.assertEqual($w.masterInterface, "wifi1");
    testing.assertEqual($w.band, "");
    testing.assertFalse($w.running);
}

func testWifiRegistrationFromRow() {
    def row as map of string to string init {
        "interface": "wifi1",
        "ssid": "My Home WiFi",
        "mac-address": "AA:BB:CC:DD:EE:FF",
        "signal": "-52",
        "uptime": "1h2m3s"
    };
    def r as WifiRegistration init wifiRegistrationFromRow($row);
    testing.assertEqual($r.interfaceName, "wifi1");
    testing.assertEqual($r.ssid, "My Home WiFi");
    testing.assertEqual($r.mac, "AA:BB:CC:DD:EE:FF");
    testing.assertEqual($r.signal, "-52");
    testing.assertEqual($r.uptime, "1h2m3s");
}
