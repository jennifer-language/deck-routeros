#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * tools example - diagnostics from the router (ping, bandwidth test).
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/tools.j
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

def p as mt.PingResult init mt.ping($c, "1.1.1.1");
if ($p.reachable) { io.printf("uplink ok: %d/%d, avg %s\n", $p.received, $p.sent, $p.avgRtt); }
else { io.printf("uplink down (loss %d percent)\n", $p.packetLoss); }

#   def bw as mt.BandwidthResult init mt.bandwidthTest($c, "192.168.88.2", 10, "both");
#   io.printf("rx %s / tx %s\n", $bw.rxAverage, $bw.txAverage);

# trace the path to a host (from the router)
def hops as list of mt.TracerouteHop init mt.traceroute($c, "1.1.1.1");
for (def h in $hops) { io.printf("hop %s %s (loss %s)\n", $h.address, $h.avgRtt, $h.loss); }

# the router's own view of its public IP, via fetch
def pubip as mt.FetchResult init mt.fetchUrl($c, "https://ifconfig.co/ip");
if ($pubip.ok) { io.printf("public IP (per the router): %s\n", $pubip.data); }

# Alerting by e-mail (needs SMTP settings - not run here):
#   mt.configureEmail($c, "10.0.9.25", 587, "router@example.org", "router", "secret");
#   mt.sendEmail($c, "noc@example.org", "router booted", "the office router just started");

mt.disconnect($c);
