#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * ipsec example - IPsec site-to-site tunnels.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/ipsec.j
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

def live as list of mt.IpsecActivePeer init mt.ipsecActive($c);
if (len($live) == 0) { io.printf("no active IPsec peers\n"); }
for (def a in $live) { io.printf("ipsec %s: %s (up %s)\n", $a.remoteAddress, $a.state, $a.uptime); }
def pols as list of mt.IpsecPolicy init mt.ipsecPolicies($c);
for (def p in $pols) { io.printf("policy %s -> %s active=%t\n", $p.srcAddress, $p.dstAddress, $p.active); }

#   mt.setupIpsecTunnel($c, "tobranch", "203.0.113.99",
#       "a long random shared secret", "192.168.10.0/24", "192.168.20.0/24");

# IKEv2 road-warrior server (native iOS/macOS/Windows clients, not run here):
#   mt.setupIkevTwoServer($c, "roadwarriors", "router-le-cert",
#       "10.200.0.10-10.200.0.200", "1.1.1.1");

mt.disconnect($c);
