#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * dhcp example - DHCP server, leases, and the WAN client.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/dhcp.j
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

def servers as list of mt.DhcpServer init mt.dhcpServers($c);
for (def s in $servers) {
    io.printf("dhcp server %s on %s\n", $s.name, $s.interfaceName);
}
def leases as list of mt.DhcpLease init mt.dhcpLeases($c);
for (def l in $leases) {
    io.printf("lease %s -> %s (%s)\n", $l.address, $l.mac, $l.status);
}
def wans as list of mt.DhcpClient init mt.dhcpClients($c);
for (def w in $wans) {
    if ($w.bound) {
        io.printf("wan %s: %s via %s\n", $w.interfaceName, $w.address, $w.gateway);
    }
}

#   mt.setupDhcp($c, "dhcplan", "brlan", "192.168.88.0/24",
#       "192.168.88.1", "192.168.88.10", "192.168.88.199", "192.168.88.1");
#   mt.setupWan($c, "ether1");

# DHCP relay: forward a network's requests to a central server
def relays as list of mt.DhcpRelay init mt.dhcpRelays($c);
for (def r in $relays) {
    io.printf("relay %s: %s -> %s\n", $r.name, $r.interfaceName, $r.dhcpServer);
}

#   mt.addDhcpRelay($c, "vlan20-relay", "vlanoffice", "10.0.0.5");

mt.disconnect($c);
