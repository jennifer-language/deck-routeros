#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * routing example - static routes and policy routing rules.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/routing.j
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

def rts as list of mt.Route init mt.routes($c);
for (def rt in $rts) {
    if (not $rt.dynamic) {
        io.printf("route %s via %s (distance %s)\n", $rt.dstAddress, $rt.gateway, $rt.distance);
    }
}
def rules as list of mt.RoutingRule init mt.routingRules($c);
for (def r in $rules) { io.printf("rule %s -> table %s (%s)\n", $r.srcAddress, $r.table, $r.action); }

#   mt.addDefaultRoute($c, "203.0.113.1", "isp uplink");
#   mt.useRoutingTable($c, "10.30.0.0/24", "backupisp", "guests via backup");

mt.disconnect($c);
