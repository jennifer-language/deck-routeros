#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * eoip example - EoIP layer-2 tunnels.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/eoip.j
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

def tunnels as list of mt.EoipTunnel init mt.eoipTunnels($c);
if (len($tunnels) == 0) { io.printf("no EoIP tunnels\n"); }
for (def t in $tunnels) {
    io.printf("eoip %s -> %s (id %d) running=%t\n", $t.name, $t.remoteAddress, $t.tunnelId, $t.running);
}

#   mt.addEoipTunnel($c, "eoipbranch", "10.100.0.2", 7);
#   mt.addBridgePort($c, "brlan", "eoipbranch");

mt.disconnect($c);
