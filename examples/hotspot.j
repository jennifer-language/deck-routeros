#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * hotspot example - the captive guest portal.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/hotspot.j
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

def portals as list of mt.HotspotServer init mt.hotspotServers($c);
for (def h in $portals) { io.printf("hotspot %s on %s (pool %s)\n", $h.name, $h.interfaceName, $h.addressPool); }
def guests as list of mt.HotspotSession init mt.hotspotActive($c);
io.printf("%d guests logged in\n", len($guests));

#   mt.setupHotspot($c, "guests", "brguest", "10.5.50.0/24",
#       "10.5.50.1", "10.5.50.10", "10.5.50.254");
#   mt.addHotspotVoucher($c, "visitor", "day pass 123", "1d", "front desk");

mt.disconnect($c);
