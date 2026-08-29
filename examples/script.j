#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * script example - the stored-script repository.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/script.j
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

def ss as list of mt.Script init mt.scripts($c);
for (def s in $ss) {
    io.printf("script %s: ran %d times, last %s\n", $s.name, $s.runCount, $s.lastStarted);
}

# Store a named script and run it (not run in the demo):
#   mt.addScript($c, "hello", ":log info \\"hello from a stored script\\"", "demo");
#   mt.runScript($c, "hello");
#   # the scheduler can run it by name: mt.scheduleDaily($c, "run-hello", "03:00:00", "hello");

mt.disconnect($c);
