#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * wireless example - classic WiFi (radios and clients).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/wireless.j
 */

use io;
use os;

import "../src/routeros.j" as mt;

def host as string init os.getEnv("MT_HOST");
def user as string init os.getEnv("MT_USER");
def password as string init os.getEnv("MT_PASSWORD");

if ($host == "" or $user == "") {
    io.printf("set MT_HOST, MT_USER and MT_PASSWORD first\n");
    exit 1;
}

def c as mt.Client init mt.connect($host, $user, $password);

def wifis as list of mt.WirelessInterface init mt.wirelessInterfaces($c);
if (len($wifis) == 0) {
    io.printf("no classic wireless interfaces\n");
}
for (def w in $wifis) {
    io.printf("wifi %s: ssid \"%s\" (%s) running=%t\n", $w.name, $w.ssid, $w.band, $w.running);
}
def clients as list of mt.WifiClient init mt.wifiClients($c);
for (def cl in $clients) {
    io.printf("client %s on %s, signal %s\n", $cl.mac, $cl.interfaceName, $cl.signalStrength);
}

#   mt.setupWifiAccessPoint($c, "wlan1", "My Home WiFi", "correct horse battery");
#   mt.addVirtualAp($c, "wlan1", "wlanguest", "Guest WiFi", "changeme123");

mt.disconnect($c);
