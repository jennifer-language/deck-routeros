#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * raw example - firewall raw rules (pre-conntrack drop / notrack).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/raw.j
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

def rules as list of mt.RawRule init mt.rawRules($c);
for (def r in $rules) {
    io.printf(
        "raw %s/%s src=%s list=%s %s\n",
        $r.chain,
        $r.action,
        $r.srcAddress,
        $r.srcAddressList,
        $r.comment);
}

# Drop a bogon/blocklist early, at the cheapest point:
#   mt.dropRawAddressList($c, "bogons", "drop bogons early");

mt.disconnect($c);
