#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * vrrp example - VRRP gateway redundancy.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/vrrp.j
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

def vrrps as list of mt.VrrpInterface init mt.vrrpInterfaces($c);
if (len($vrrps) == 0) { io.printf("no VRRP configured\n"); }
for (def v in $vrrps) {
    if ($v.master) { io.printf("vrrp %s: MASTER for vrid %d on %s\n", $v.name, $v.vrid, $v.interfaceName); }
    else { io.printf("vrrp %s: backup (priority %d)\n", $v.name, $v.priority); }
}

#   mt.setupVrrp($c, "vrrplan", "brlan", 10, 200, "192.168.88.254/32");

mt.disconnect($c);
