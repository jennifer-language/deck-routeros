#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * disk example - storage devices (USB/NVMe/SATA).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/disk.j
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

def ds as list of mt.Disk init mt.disks($c);
if (len($ds) == 0) {
    io.printf("no attached storage\n");
}
for (def d in $ds) {
    # name falls back to slot - RouterOS leaves "name" empty on USB storage
    io.printf(
        "disk %s (slot %s, %s) fs=%s size=%d free=%d\n",
        $d.name,
        $d.slot,
        $d.model,
        $d.fs,
        $d.sizeBytes,
        $d.freeBytes);
}

# DESTRUCTIVE - erases the whole disk (not run in the demo):
#   mt.formatDisk($c, "usb1", "ext4", "container-storage");
#   mt.ejectDisk($c, "usb1");

mt.disconnect($c);
