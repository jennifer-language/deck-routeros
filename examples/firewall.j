#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * firewall example - filter rules.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/firewall.j
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

def rules as list of mt.FirewallRule init mt.firewallRules($c);
for (def r in $rules) {
    io.printf("%s %s %s -> %s %s\n", $r.chain, $r.action, $r.srcAddress, $r.dstAddress, $r.comment);
}

#   mt.allowService($c, "tcp", 22, "ssh management");
#   mt.blockAddress($c, "203.0.113.7", "known scanner");
#   def dr as mt.FirewallRule init mt.firewallRule(mt.CHAIN_FORWARD, mt.ACTION_DROP);
#   $dr = mt.withProtocol($dr, "tcp");  $dr = mt.withDstPort($dr, "445");
#   mt.addFirewallRule($c, $dr);

# match a whole interface list (the v7 WAN/LAN pattern - see interfacelist):
#   def wr as mt.FirewallRule init mt.firewallRule(mt.CHAIN_INPUT, mt.ACTION_DROP);
#   $wr = mt.withInInterfaceList($wr, "WAN");
#   $wr = mt.withComment($wr, "drop unsolicited from WAN");
#   mt.addFirewallRule($c, $wr);

mt.disconnect($c);
