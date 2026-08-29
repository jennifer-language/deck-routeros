#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * ethernet example - ethernet port settings and live link state.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/ethernet.j
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

def ports as list of mt.EthernetPort init mt.ethernetPorts($c);
for (def p in $ports) {
    io.printf("port %s (%s) running=%t poe=%s\n", $p.name, $p.defaultName, $p.running, $p.poeOut);
}
if (len($ports) > 0) {
    def ls as mt.LinkStatus init mt.linkStatus($c, $ports[0].name);
    io.printf("link %s: %s at %s full-duplex=%t\n", $ls.name, $ls.status, $ls.rate, $ls.fullDuplex);
}

#   mt.setPoe($c, "ether5", "off");       # power-cycle a hung PoE device
#   mt.setPoe($c, "ether5", "auto-on");
#   mt.forceEthernetLink($c, "ether4", "100Mbps", true);

mt.disconnect($c);
