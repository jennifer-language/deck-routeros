#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * mangle example - packet marking.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/mangle.j
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

def mangles as list of mt.MangleRule init mt.mangleRules($c);
for (def m in $mangles) {
    io.printf(
        "%s/%s marks=%s%s%s %s\n",
        $m.chain,
        $m.action,
        $m.newConnectionMark,
        $m.newPacketMark,
        $m.newRoutingMark,
        $m.comment);
}

#   def mk as mt.FirewallRule init mt.firewallRule(mt.CHAIN_PREROUTING, mt.ACTION_ACCEPT);
#   $mk = mt.withProtocol($mk, "udp");  $mk = mt.withDstPort($mk, "5060-5200");
#   mt.setupPacketMark($c, "voip", $mk);
#   mt.clampTcpMss($c, "pppoewan");

mt.disconnect($c);
