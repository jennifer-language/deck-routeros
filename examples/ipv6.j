#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * ipv6 example - the IPv6 stack: settings, addresses, advertisements.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/ipv6.j
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

def s as mt.Ipv6Settings init mt.ipv6Settings($c);
io.printf("ipv6 disabled=%t forward=%t acceptRA=%t\n",
    $s.disabled, $s.forward, $s.acceptRouterAdvertisements);

if ($s.disabled) {
    io.printf("  the stack is off - nothing else to report\n");
} else {
    def addrs as list of mt.Ipv6Address init mt.ipv6Addresses($c);
    io.printf("addresses (%d):\n", len($addrs));
    for (def a in $addrs) {
        def origin as string init "static";
        if ($a.dynamic) { $origin = "dynamic"; }
        io.printf("  %-30s %-10s %s advertise=%t\n",
            $a.address, $a.interfaceName, $origin, $a.advertise);
    }

    def nd as list of mt.Ipv6Nd init mt.ipv6Nd($c);
    io.printf("advertisements (%d):\n", len($nd));
    for (def n in $nd) {
        io.printf("  %-10s M=%t O=%t dns=%t disabled=%t\n",
            $n.interfaceName, $n.managed, $n.otherConfig, $n.advertiseDns, $n.disabled);
    }
}

# Address a LAN and let clients configure themselves by SLAAC:
#   mt.enableIpv6($c);                                    # needs a reboot to fully apply
#   mt.setIpv6Forwarding($c, true);
#   mt.addIpv6Address($c, "2001:db8:1::1/64", "brlan");   # a LAN prefix is always a /64
#   mt.advertiseIpv6On($c, "brlan");
#   mt.setIpv6NdFlags($c, "brlan", false, true);          # SLAAC, DNS from DHCPv6

# Or close it down on a v4-only network - remember the /ip/firewall
# rules never filtered v6 in the first place:
#   mt.disableIpv6($c);

mt.disconnect($c);
