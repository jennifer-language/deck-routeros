#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * users example - router accounts, groups, and active sessions.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/users.j
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

def accounts as list of mt.User init mt.users($c);
for (def u in $accounts) {
    io.printf("user %s (%s) disabled=%t last login %s\n", $u.name, $u.group, $u.disabled, $u.lastLoggedIn);
}
def sessions as list of mt.UserSession init mt.activeUsers($c);
for (def s in $sessions) { io.printf("active: %s via %s from %s\n", $s.name, $s.via, $s.address); }

#   mt.addUser($c, "monitoring", "a long random password", mt.GROUP_READ);
#   mt.restrictUser($c, "monitoring", "10.0.9.0/24");

mt.disconnect($c);
