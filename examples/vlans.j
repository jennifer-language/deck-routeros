#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * vlans example - 802.1Q tagged interfaces.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/vlans.j
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

def vs as list of mt.Vlan init mt.vlans($c);
if (len($vs) == 0) { io.printf("no VLAN interfaces\n"); }
for (def v in $vs) {
    io.printf("vlan %s: tag %d on %s running=%t\n", $v.name, $v.vlanId, $v.interfaceName, $v.running);
}

#   mt.addVlan($c, "vlanoffice", 20, "ether2");
#   mt.addIpAddress($c, "10.20.0.1/24", "vlanoffice");

# the modern (VLAN-aware bridge) model - bridge VLAN table
def bvs as list of mt.BridgeVlan init mt.bridgeVlans($c);
for (def bv in $bvs) {
    io.printf("bridge %s vlan %s tagged=%s untagged=%s\n", $bv.bridge, $bv.vlanIds, $bv.tagged, $bv.untagged);
}

# Build a VLAN-aware bridge (table + pvids FIRST, filtering LAST):
#   mt.addBridgeVlan($c, "brlan", 10, "ether1", "ether2,ether3");
#   mt.setPortPvid($c, "brlan", "ether2", 10);
#   mt.enableVlanFiltering($c, "brlan");

mt.disconnect($c);
