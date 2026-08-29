#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * ip example - IP addresses on interfaces.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/ip.j
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

def addrs as list of mt.IpAddress init mt.ipAddresses($c);
for (def a in $addrs) {
    io.printf("%s on %s dynamic=%t %s\n", $a.address, $a.interfaceName, $a.dynamic, $a.comment);
}

#   mt.addIpAddress($c, "192.168.88.1/24", "brlan");
#   mt.removeIpAddress($c, "192.168.88.1/24");

mt.disconnect($c);
