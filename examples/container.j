#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * container example - OCI containers on the router (v7).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/container.j
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

def cts as list of mt.Container init mt.containers($c);
if (len($cts) == 0) { io.printf("no containers (or the feature is not enabled)\n"); }
for (def ct in $cts) { io.printf("container %s (%s): %s\n", $ct.name, $ct.tag, $ct.status); }

#   mt.addContainer($c, "pihole", "pihole/pihole:latest", "veth1", "usb1/pihole");
#   mt.startContainer($c, "pihole");

mt.disconnect($c);
