# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the wireless topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testEnsureSsidAcceptsSpacesAndLimit() {
    ensureSsid("My Home WiFi");
    ensureSsid("x");
    ensureSsid("abcdefghijklmnopqrstuvwxyzabcdef");
    testing.assertTrue(true);
}

func failEnsureSsidEmpty() {
    ensureSsid("   ");
}

func testEnsureSsidRejectsEmpty() {
    testing.assertThrows("failEnsureSsidEmpty", "routeros");
}

func failEnsureSsidTooLong() {
    ensureSsid("abcdefghijklmnopqrstuvwxyzabcdefg");
}

func testEnsureSsidRejectsTooLong() {
    testing.assertThrows("failEnsureSsidTooLong", "routeros");
}

func testEnsureWifiPasswordAcceptsBounds() {
    ensureWifiPassword("12345678");
    ensureWifiPassword("abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijk");
    testing.assertTrue(true);
}

func failEnsureWifiPasswordTooShort() {
    ensureWifiPassword("1234567");
}

func testEnsureWifiPasswordRejectsTooShort() {
    testing.assertThrows("failEnsureWifiPasswordTooShort", "routeros");
}

func failEnsureWifiPasswordTooLong() {
    ensureWifiPassword("abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijkl");
}

func testEnsureWifiPasswordRejectsTooLong() {
    testing.assertThrows("failEnsureWifiPasswordTooLong", "routeros");
}

func testWifiProfileNameIsDeterministic() {
    testing.assertEqual(wifiProfileName("wlan1"), "routeros-wlan1");
    testing.assertEqual(wifiProfileName("wlanguest"), "routeros-wlanguest");
}

func testWirelessFromRowPhysicalRadio() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "wlan1",
        "ssid": "My Home WiFi",
        "mode": "ap-bridge",
        "band": "5ghz-a/n/ac",
        "frequency": "auto",
        "security-profile": "routeros-wlan1",
        "running": "true",
        "disabled": "false",
        "comment": "living room"
    };
    def w as WirelessInterface init wirelessFromRow($row);
    testing.assertEqual($w.id, "*1");
    testing.assertEqual($w.name, "wlan1");
    testing.assertEqual($w.ssid, "My Home WiFi");
    testing.assertEqual($w.mode, "ap-bridge");
    testing.assertEqual($w.band, "5ghz-a/n/ac");
    testing.assertEqual($w.frequency, "auto");
    testing.assertEqual($w.securityProfile, "routeros-wlan1");
    testing.assertEqual($w.masterInterface, "");
    testing.assertTrue($w.running);
    testing.assertFalse($w.disabled);
    testing.assertEqual($w.comment, "living room");
}

func testWirelessFromRowVirtualAp() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "wlanguest",
        "ssid": "Guest",
        "master-interface": "wlan1",
        "disabled": "false"
    };
    def w as WirelessInterface init wirelessFromRow($row);
    testing.assertEqual($w.masterInterface, "wlan1");
    testing.assertEqual($w.band, "");
    testing.assertFalse($w.running);
}

func testWifiClientFromRow() {
    def row as map of string to string init {
        "interface": "wlan1",
        "mac-address": "AA:BB:CC:DD:EE:FF",
        "signal-strength": "-52dBm",
        "tx-rate": "866Mbps",
        "rx-rate": "780Mbps",
        "uptime": "1h2m3s"
    };
    def w as WifiClient init wifiClientFromRow($row);
    testing.assertEqual($w.interfaceName, "wlan1");
    testing.assertEqual($w.mac, "AA:BB:CC:DD:EE:FF");
    testing.assertEqual($w.signalStrength, "-52dBm");
    testing.assertEqual($w.txRate, "866Mbps");
    testing.assertEqual($w.rxRate, "780Mbps");
    testing.assertEqual($w.uptime, "1h2m3s");
}
