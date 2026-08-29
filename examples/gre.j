#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * gre example - GRE routed tunnels.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/gre.j
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

def tunnels as list of mt.GreTunnel init mt.greTunnels($c);
if (len($tunnels) == 0) {
    io.printf("no GRE tunnels\n");
}
for (def t in $tunnels) {
    io.printf("gre %s -> %s running=%t\n", $t.name, $t.remoteAddress, $t.running);
}

#   mt.addGreTunnel($c, "grebranch", "203.0.113.99");
#   mt.addIpAddress($c, "10.99.0.1/30", "grebranch");
#   mt.addRoute($c, "192.168.20.0/24", "10.99.0.2", "branch LAN via GRE");

mt.disconnect($c);
