#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * nat example - masquerade and port forwarding.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/nat.j
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

def nats as list of mt.NatRule init mt.natRules($c);
for (def n in $nats) {
    io.printf(
        "%s/%s dst-port %s -> %s:%s %s\n",
        $n.chain,
        $n.action,
        $n.dstPort,
        $n.toAddresses,
        $n.toPorts,
        $n.comment);
}

#   mt.addMasquerade($c, "ether1", "lan to internet");
#   mt.forwardPortOn($c, "ether1", "tcp", 8080, "192.168.88.10", 80, "web server");

mt.disconnect($c);
