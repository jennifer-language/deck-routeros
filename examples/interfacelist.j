#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * interfacelist example - interface lists (WAN/LAN groups for firewall).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/interfacelist.j
 */

use io;
use os;
use strings;

import "../src/routeros.j" as mt;

def host as string init os.getEnv("MT_HOST");
def user as string init os.getEnv("MT_USER");
def password as string init os.getEnv("MT_PASSWORD");

if ($host == "" or $user == "") {
    io.printf("set MT_HOST, MT_USER and MT_PASSWORD first\n");
    exit 1;
}

def c as mt.Client init mt.connect($host, $user, $password);

def ils as list of mt.InterfaceList init mt.interfaceLists($c);
for (def il in $ils) {
    def members as list of string init mt.interfaceListMembers($c, $il.name);
    io.printf("list %s: %s\n", $il.name, strings.join($members, ", "));
}

#   mt.addInterfaceList($c, "WAN", "internet-facing ports");
#   mt.addToInterfaceList($c, "WAN", "ether1");

mt.disconnect($c);
