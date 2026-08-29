#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * netwatch example - continuous host monitoring.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/netwatch.j
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

def watches as list of mt.NetwatchHost init mt.netwatchHosts($c);
for (def n in $watches) {
    io.printf("netwatch %s (%s): %s since %s\n", $n.host, $n.comment, $n.status, $n.since);
}
def down as list of mt.NetwatchHost init mt.downHosts($c);
io.printf("%d watched hosts are down\n", len($down));

#   mt.watchHostScripted($c, "192.168.88.50",
#       ":log warning \"printer down\"", ":log info \"printer back\"", "printer");

mt.disconnect($c);
