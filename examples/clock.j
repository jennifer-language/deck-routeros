#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * clock example - clock and NTP.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/clock.j
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

def ck as mt.Clock init mt.clock($c);
def ntp as mt.NtpStatus init mt.ntpStatus($c);
io.printf("clock: %s %s (%s), ntp synced=%t\n", $ck.date, $ck.time, $ck.timezone, $ntp.synced);

#   mt.useNtp($c, "pool.ntp.org");
#   mt.setTimezone($c, "Europe/Berlin");

mt.disconnect($c);
