#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * interfaces example - listing and managing interfaces.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/interfaces.j
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

def ifaces as list of mt.Interface init mt.interfaces($c);
for (def i in $ifaces) {
    io.printf("%s (%s) running=%t disabled=%t %s\n",
        $i.name, $i.kind, $i.running, $i.disabled, $i.comment);
}

#   mt.commentInterface($c, "ether1", "uplink to ISP");
#   mt.disableInterface($c, "ether5");
#   mt.renameInterface($c, "ether2", "lan1");

mt.disconnect($c);
