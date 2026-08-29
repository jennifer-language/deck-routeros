#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * l2tp example - L2TP remote-access VPN server and clients.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/l2tp.j
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

def s as mt.L2tpServer init mt.l2tpServerStatus($c);
io.printf("l2tp server enabled=%t ipsec=%t\n", $s.enabled, $s.useIpsec);
def clients as list of mt.L2tpClient init mt.l2tpClients($c);
for (def cl in $clients) {
    io.printf("l2tp client %s -> %s running=%t\n", $cl.name, $cl.connectTo, $cl.running);
}
def sessions as list of mt.PppSession init mt.pppActive($c);
for (def sess in $sessions) {
    io.printf("connected: %s (%s) from %s\n", $sess.name, $sess.service, $sess.callerId);
}

#   mt.enableL2tpServer($c, "a long random ipsec secret");
#   mt.addVpnUser($c, "alice", "her password", "l2tp", "field laptop");

mt.disconnect($c);
