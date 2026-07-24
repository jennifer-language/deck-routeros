#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * log example - reading the router log.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/log.j
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

def tail as list of mt.LogEntry init mt.recentLogEntries($c, 10);
for (def e in $tail) { io.printf("%s [%s] %s\n", $e.time, $e.topics, $e.message); }
def problems as list of mt.LogEntry init mt.logErrors($c);
io.printf("%d error/critical entries in the log buffer\n", len($problems));

#   mt.addLoggingRule($c, "firewall", "disk");
#   mt.setupRemoteLogging($c, "192.168.88.40", 514, "info,warning,error,critical");

mt.disconnect($c);
