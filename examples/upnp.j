#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * upnp example - UPnP (LAN devices open their own port forwards).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/upnp.j
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

def s as mt.UpnpSettings init mt.upnpStatus($c);
io.printf("upnp enabled=%t\n", $s.enabled);
def ifs as list of mt.UpnpInterface init mt.upnpInterfaces($c);
for (def i in $ifs) {
    io.printf("  %s: %s\n", $i.interfaceName, $i.role);
}

# Enable (weigh the security cost - any LAN device can open a hole):
#   mt.enableUpnp($c);
#   mt.setUpnpInterface($c, "ether1", "external");
#   mt.setUpnpInterface($c, "brlan", "internal");

mt.disconnect($c);
