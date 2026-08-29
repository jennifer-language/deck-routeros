#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * trafficflow example - NetFlow / IPFIX export to a collector.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/trafficflow.j
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

def s as mt.TrafficFlowSettings init mt.trafficFlowStatus($c);
io.printf("traffic-flow enabled=%t on %s\n", $s.enabled, $s.interfaces);
def ts as list of mt.FlowTarget init mt.flowTargets($c);
for (def t in $ts) {
    io.printf("  export v%s -> %s:%s\n", $t.version, $t.address, $t.port);
}

#   mt.enableTrafficFlow($c);
#   mt.addFlowTarget($c, "10.0.9.30", 2055, "ipfix");

mt.disconnect($c);
