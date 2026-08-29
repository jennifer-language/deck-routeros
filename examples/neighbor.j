#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * neighbor example - discovered neighbors (LLDP/CDP/MNDP).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/neighbor.j
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

def ns as list of mt.Neighbor init mt.neighbors($c);
if (len($ns) == 0) {
    io.printf("no neighbors discovered\n");
}
for (def n in $ns) {
    io.printf(
        "%s: %s (%s %s) at %s on %s\n",
        $n.identity,
        $n.platform,
        $n.board,
        $n.version,
        $n.address,
        $n.interfaceName);
}

mt.disconnect($c);
