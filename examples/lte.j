#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * lte example - LTE / cellular uplink (signal, registration).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/lte.j
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

def ltes as list of mt.LteInterface init mt.lteInterfaces($c);
if (len($ltes) == 0) { io.printf("no LTE modem on this router\n"); }
for (def l in $ltes) {
    io.printf("lte %s running=%t\n", $l.name, $l.running);
    def s as mt.LteStatus init mt.lteStatus($c, $l.name);
    io.printf("  %s on %s (%s), RSRP %s SINR %s\n",
        $s.status, $s.operator, $s.accessTechnology, $s.rsrp, $s.sinr);
}

#   mt.setLteApn($c, "lte1", "internet");

mt.disconnect($c);
