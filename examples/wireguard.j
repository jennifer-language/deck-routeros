#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * wireguard example - WireGuard VPN tunnels.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/wireguard.j
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

def wgs as list of mt.WireguardInterface init mt.wireguardInterfaces($c);
for (def wg in $wgs) {
    io.printf("wireguard %s on udp %d, key %s\n", $wg.name, $wg.listenPort, $wg.publicKey);
}
def peers as list of mt.WireguardPeer init mt.wireguardPeers($c);
for (def p in $peers) {
    io.printf("  peer %s: allowed %s, handshake %s\n", $p.comment, $p.allowedAddress, $p.lastHandshake);
}

#   mt.setupWireguardServer($c, "wgvpn", 13231, "10.100.0.1/24");
#   io.printf("server key: %s\n", mt.wireguardPublicKey($c, "wgvpn"));
#   mt.addWireguardPeer($c, "wgvpn", "<laptop key>", "10.100.0.2/32", "laptop");

mt.disconnect($c);
