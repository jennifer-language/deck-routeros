#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * ppp example - PPPoE dial-in WAN (DSL/fibre).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/ppp.j
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

def dsls as list of mt.PppoeClient init mt.pppoeClients($c);
if (len($dsls) == 0) {
    io.printf("no PPPoE clients\n");
}
for (def d in $dsls) {
    if ($d.running) {
        io.printf("pppoe %s: connected as %s over %s\n", $d.name, $d.user, $d.interfaceName);
    } else {
        io.printf("pppoe %s: down\n", $d.name);
    }
}

#   mt.setupPppoe($c, "pppoewan", "ether1", "user@provider.example", "secret");
#   mt.addMasquerade($c, "pppoewan", "lan to internet");

# the shared VPN/dial-in user database (used by L2TP/SSTP/OpenVPN servers)
def vusers as list of mt.PppUser init mt.vpnUsers($c);
for (def u in $vusers) {
    io.printf("vpn user %s (service %s, profile %s)\n", $u.name, $u.service, $u.profile);
}

#   mt.addVpnUser($c, "alice", "her password", "any", "field laptop");

# the router as a PPPoE concentrator (accept dial-ins)
def srvs as list of mt.PppoeServer init mt.pppoeServers($c);
for (def s in $srvs) {
    io.printf("pppoe server \"%s\" on %s\n", $s.serviceName, $s.interfaceName);
}

#   mt.addPppoeServer($c, "office", "ether2");
#   mt.addVpnUser($c, "branch", "a password", "pppoe", "downstream router");

mt.disconnect($c);
