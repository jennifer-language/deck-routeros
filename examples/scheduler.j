#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * scheduler example - scripts on a timer.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/scheduler.j
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

def tasks as list of mt.ScheduledTask init mt.scheduledTasks($c);
for (def t in $tasks) {
    io.printf(
        "task %s: every %s, next %s, ran %d times\n",
        $t.name,
        $t.interval,
        $t.nextRun,
        $t.runCount);
}

#   mt.scheduleDaily($c, "nightly-backup", "03:00:00", "/system backup save name=nightly");

mt.disconnect($c);
