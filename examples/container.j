#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

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
if (len($cts) == 0) {
    io.printf("no containers (or the feature is not enabled)\n");
}
for (def ct in $cts) {
    io.printf(
        "container %s (%s): %s envs=%s mounts=%s\n",
        $ct.name,
        $ct.tag,
        $ct.status,
        $ct.envLists,
        $ct.mountLists);
}

def envs as list of mt.ContainerEnv init mt.containerEnvs($c);
for (def e in $envs) {
    io.printf("env %s: %s=%s\n", $e.listName, $e.key, $e.value);
}

def mounts as list of mt.ContainerMount init mt.containerMounts($c);
for (def m in $mounts) {
    io.printf("mount %s: %s -> %s\n", $m.listName, $m.src, $m.dst);
}

# create the config lists first, attach them, then start:
#   mt.addContainerEnv($c, "pihole-env", "TZ", "Europe/Vienna");
#   mt.addContainerMount($c, "pihole-etc", "usb1/pihole/etc", "/etc/pihole");
#   mt.addContainer($c, "pihole", "pihole/pihole:latest", "veth1", "usb1/pihole");
#   mt.setContainerEnvLists($c, "pihole", ["pihole-env"]);
#   mt.setContainerMountLists($c, "pihole", ["pihole-etc"]);
#   mt.startContainer($c, "pihole");

mt.disconnect($c);
