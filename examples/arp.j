#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * arp example - the ARP table (who is on the LAN).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/arp.j
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

def neighbours as list of mt.ArpEntry init mt.arpTable($c);
for (def n in $neighbours) {
    if ($n.complete) {
        io.printf("arp %s -> %s on %s dynamic=%t\n", $n.address, $n.mac, $n.interfaceName, $n.dynamic);
    }
}

#   mt.addStaticArp($c, "192.168.88.50", "AA:BB:CC:DD:EE:FF", "brlan");
#   io.printf("%s\n", mt.macForAddress($c, "192.168.88.50"));

mt.disconnect($c);
