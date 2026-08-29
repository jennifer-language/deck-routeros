#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * radius example - central authentication via RADIUS.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/radius.j
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

def servers as list of mt.RadiusServer init mt.radiusServers($c);
if (len($servers) == 0) {
    io.printf("no RADIUS servers configured\n");
}
for (def s in $servers) {
    io.printf("radius %s for %s\n", $s.address, $s.services);
}

#   mt.addRadiusServer($c, "10.0.9.20", "a shared secret", "login,ppp", "AD");

mt.disconnect($c);
