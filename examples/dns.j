#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * dns example - DNS resolver settings, static entries, and the cache.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/dns.j
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

def dns as mt.DnsSettings init mt.dnsSettings($c);
io.printf("dns servers: %s (remote=%t, cache %s of %s)\n",
    $dns.servers, $dns.allowRemoteRequests, $dns.cacheUsed, $dns.cacheSize);
def cached as list of mt.DnsCacheEntry init mt.dnsCacheFor($c, "example.org");
for (def rec in $cached) { io.printf("cache: %s %s -> %s\n", $rec.kind, $rec.name, $rec.data); }

#   mt.setDnsServers($c, "1.1.1.1,9.9.9.9");
#   mt.allowRemoteDnsRequests($c, true);
#   mt.addDnsEntry($c, "nas.lan", "192.168.88.50");
#   mt.flushDnsCache($c);

# ad/malware blocklists (RouterOS 7.15+)
def adlists as list of mt.DnsAdlist init mt.dnsAdlists($c);
for (def a in $adlists) { io.printf("adlist %s blocks %s names\n", $a.url, $a.matchCount); }

#   mt.addAdlist($c, "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts");

mt.disconnect($c);
