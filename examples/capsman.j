#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * capsman example - central management of many access points (CAPsMAN).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/capsman.j
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

def st as mt.CapsmanStatus init mt.capsmanStatus($c);
if ($st.version == 0) { io.printf("no CAPsMAN on this router\n"); }
else { io.printf("CAPsMAN v%d enabled=%t, %d managed APs\n", $st.version, $st.enabled, $st.managedAps); }
def aps as list of mt.ManagedAp init mt.managedAps($c);
for (def ap in $aps) { io.printf("AP %s at %s: %s\n", $ap.identity, $ap.address, $ap.state); }

#   mt.enableCapsman($c);   # then configuration + provisioning via generic verbs

mt.disconnect($c);
