#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * cloud example - MikroTik Cloud DDNS.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/cloud.j
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

def cloud as mt.CloudStatus init mt.cloudStatus($c);
if ($cloud.ddnsEnabled) {
    io.printf("cloud ddns: %s -> %s\n", $cloud.dnsName, $cloud.publicAddress);
} else {
    io.printf("cloud ddns is off\n");
}

#   mt.enableCloudDns($c);
#   io.printf("dial this: %s\n", mt.routerDnsName($c));

mt.disconnect($c);
