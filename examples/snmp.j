#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * snmp example - SNMP for monitoring.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/snmp.j
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

def snmp as mt.SnmpSettings init mt.snmpSettings($c);
io.printf(
    "snmp enabled=%t, contact=%s, location=%s\n",
    $snmp.enabled,
    $snmp.contact,
    $snmp.location);
def coms as list of mt.SnmpCommunity init mt.snmpCommunities($c);
for (def com in $coms) {
    io.printf("community %s from %s\n", $com.name, $com.addresses);
}

#   mt.enableSnmp($c, "mon4711", "10.0.9.0/24");
#   mt.setSnmpInfo($c, "noc@example.org", "rack 3, office Berlin");

mt.disconnect($c);
