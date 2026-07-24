#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * core example - connecting and the generic verbs.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/core.j
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

# the generic verbs reach any RouterOS path, typed helpers or not
def rows as list of map of string to string init mt.getAll($c, "/system/resource");
for (def row in $rows) {
    io.printf("board %s, version %s\n", $row["board-name"], $row["version"]);
}
io.printf("ether1 id: %s\n", mt.idByName($c, "/interface", "ether1"));

# create/change/delete anything via the verbs (not run here):
#   def id as string init mt.add($c, "/ip/address", {"address": "10.0.0.1/24", "interface": "ether2"});
#   mt.set($c, "/ip/address", $id, {"comment": "test"});
#   mt.remove($c, "/ip/address", $id);

mt.disconnect($c);
