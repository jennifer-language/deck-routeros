#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * services example - management services (hardening the ways in).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/services.j
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

def svcs as list of mt.Service init mt.services($c);
for (def s in $svcs) {
    if (not $s.disabled) {
        if ($s.address == "") { io.printf("service %s port %d: open to anywhere\n", $s.name, $s.port); }
        else { io.printf("service %s port %d: restricted to %s\n", $s.name, $s.port, $s.address); }
    }
}

#   mt.disableInsecureServices($c);            # telnet + ftp off
#   mt.restrictService($c, "winbox", "10.0.9.0/24");
#   mt.setServicePort($c, "ssh", 2200);

mt.disconnect($c);
