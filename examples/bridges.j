#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * bridges example - bridges and bridge ports (virtual switches).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/bridges.j
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

def brs as list of mt.Bridge init mt.bridges($c);
for (def b in $brs) {
    io.printf("bridge %s running=%t\n", $b.name, $b.running);
    def ports as list of mt.BridgePort init mt.bridgePorts($c, $b.name);
    for (def p in $ports) {
        io.printf("  port: %s\n", $p.interfaceName);
    }
}

#   mt.addBridge($c, "brlan");
#   mt.addBridgePort($c, "brlan", "ether2");
#   mt.addIpAddress($c, "192.168.88.1/24", "brlan");

mt.disconnect($c);
