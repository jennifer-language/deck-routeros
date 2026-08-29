#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * switch example - switch chip inventory and hardware-offload check.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/switch.j
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

# does this board have a switch chip?
def chips as list of mt.SwitchChip init mt.switchChips($c);
if (len($chips) == 0) {
    io.printf("no switch chip (pure-CPU forwarding)\n");
}
for (def ch in $chips) {
    io.printf("switch %s (%s)\n", $ch.name, $ch.kind);
}

# which bridge ports are allowed to offload?
def ports as list of mt.BridgePort init mt.bridgePorts($c, "brlan");
for (def p in $ports) {
    io.printf("port %s: hardware-offload=%t\n", $p.interfaceName, $p.hardwareOffload);
}

# proof the chip is actually forwarding: its hardware MAC table
def hosts as list of mt.SwitchHost init mt.switchHosts($c);
io.printf("%d MACs in the switch chip host table\n", len($hosts));

# Force a port to software forwarding (rarely wanted):
#   mt.setBridgePortHardwareOffload($c, "ether2", false);

mt.disconnect($c);
