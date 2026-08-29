#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * contrack example - the live connection-tracking table.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/contrack.j
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

def s as mt.ConntrackSettings init mt.conntrackSettings($c);
io.printf("conntrack %s: %d of %d entries\n", $s.enabled, $s.totalEntries, $s.maxEntries);
# what one host is talking to (read-only)
def conns as list of mt.Connection init mt.connectionsFor($c, "192.168.88.1");
for (def con in $conns) {
    io.printf("%s %s -> %s %s\n", $con.protocol, $con.srcAddress, $con.dstAddress, $con.tcpState);
}

#   mt.dropConnectionsFor($c, "192.168.88.55");   # cut a host off

mt.disconnect($c);
