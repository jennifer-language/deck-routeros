#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * ovpn example - OpenVPN remote-access VPN server and clients.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/ovpn.j
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

def s as mt.OvpnServer init mt.ovpnServerStatus($c);
io.printf("ovpn server enabled=%t port=%d mode=%s\n", $s.enabled, $s.port, $s.mode);
def clients as list of mt.OvpnClient init mt.ovpnClients($c);
for (def cl in $clients) {
    io.printf("ovpn client %s -> %s running=%t\n", $cl.name, $cl.connectTo, $cl.running);
}

#   mt.enableOvpnServer($c, "router-le-cert", 1194);
#   mt.addVpnUser($c, "carol", "her password", "ovpn", "laptop");

mt.disconnect($c);
