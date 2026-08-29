#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * bonding example - link aggregation.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/bonding.j
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

def bnds as list of mt.Bond init mt.bonds($c);
if (len($bnds) == 0) {
    io.printf("no bonds configured\n");
}
for (def bn in $bnds) {
    io.printf("bond %s (%s) over %s running=%t\n", $bn.name, $bn.mode, $bn.slaves, $bn.running);
}

#   mt.addLacpBond($c, "bondtrunk", "ether1,ether2");
#   mt.addFailoverBond($c, "bonduplink", "ether1,ether2", "ether1");

mt.disconnect($c);
