#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * queues example - simple queues and hierarchical QoS.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/queues.j
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

def sq as list of mt.SimpleQueue init mt.simpleQueues($c);
for (def q in $sq) {
    io.printf("queue %s on %s: %s up / %s down\n", $q.name, $q.target, $q.maxUpload, $q.maxDownload);
}
def tq as list of mt.TreeQueue init mt.treeQueues($c);
for (def t in $tq) {
    io.printf("tree %s under %s: mark=%s max=%s prio=%d\n",
        $t.name, $t.parent, $t.packetMark, $t.maxLimit, $t.priority);
}

#   mt.limitBandwidth($c, "guest-wifi", "192.168.90.0/24", "5M", "20M");
#   mt.addQueueTreeRoot($c, "qosup", "pppoewan", "38M");
#   mt.addQueueTreeChild($c, "qosupvoip", "qosup", "voip", "5M", "38M", 1);

mt.disconnect($c);
