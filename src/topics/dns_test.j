# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the dns topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testDnsSettingsFromRow() {
    def row as map of string to string init {
        "servers": "1.1.1.1,9.9.9.9",
        "allow-remote-requests": "true",
        "cache-size": "2048KiB",
        "cache-used": "53KiB"
    };
    def d as DnsSettings init dnsSettingsFromRow($row);
    testing.assertEqual($d.servers, "1.1.1.1,9.9.9.9");
    testing.assertTrue($d.allowRemoteRequests);
    testing.assertEqual($d.cacheSize, "2048KiB");
    testing.assertEqual($d.cacheUsed, "53KiB");
}

func testDnsEntryFromRow() {
    def row as map of string to string init {
        ".id": "*5",
        "name": "nas.lan",
        "address": "192.168.88.50",
        "ttl": "1d",
        "disabled": "false",
        "comment": "storage box"
    };
    def e as DnsEntry init dnsEntryFromRow($row);
    testing.assertEqual($e.id, "*5");
    testing.assertEqual($e.name, "nas.lan");
    testing.assertEqual($e.address, "192.168.88.50");
    testing.assertEqual($e.ttl, "1d");
    testing.assertFalse($e.disabled);
    testing.assertEqual($e.comment, "storage box");
}

func testDnsCacheEntryFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "example.org",
        "type": "A",
        "data": "93.184.216.34",
        "ttl": "23m11s",
        "static": "false"
    };
    def e as DnsCacheEntry init dnsCacheEntryFromRow($row);
    testing.assertEqual($e.id, "*1");
    testing.assertEqual($e.name, "example.org");
    testing.assertEqual($e.kind, "A");
    testing.assertEqual($e.data, "93.184.216.34");
    testing.assertEqual($e.ttl, "23m11s");
    testing.assertFalse($e.isStatic);
}

func testDnsCacheEntryFromStaticRow() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "nas.lan",
        "type": "A",
        "data": "192.168.88.50",
        "static": "true"
    };
    def e as DnsCacheEntry init dnsCacheEntryFromRow($row);
    testing.assertTrue($e.isStatic);
    testing.assertEqual($e.ttl, "");
}

func testCacheRowsForNameIsCaseInsensitive() {
    def rows as list of map of string to string init [
        {"name": "Example.ORG", "type": "A", "data": "93.184.216.34"},
        {"name": "other.org", "type": "A", "data": "192.0.2.1"},
        {"name": "example.org", "type": "AAAA", "data": "2606:2800:220:1::1"}
    ];
    def hits as list of map of string to string init cacheRowsForName($rows, "example.org");
    testing.assertEqual(len($hits), 2);
    testing.assertEqual(rowValue($hits[0], "data"), "93.184.216.34");
    testing.assertEqual(rowValue($hits[1], "data"), "2606:2800:220:1::1");
}

func testCacheRowsForNameMissIsEmpty() {
    def rows as list of map of string to string init [
        {"name": "example.org", "type": "A", "data": "93.184.216.34"}
    ];
    testing.assertEqual(len(cacheRowsForName($rows, "unknown.example")), 0);
}

func testAddressesFromCacheRowsSkipsCname() {
    def rows as list of map of string to string init [
        {"name": "www.example.org", "type": "CNAME", "data": "example.org"},
        {"name": "www.example.org", "type": "A", "data": "93.184.216.34"},
        {"name": "www.example.org", "type": "AAAA", "data": "2606:2800:220:1::1"}
    ];
    def addrs as list of string init addressesFromCacheRows($rows, "www.example.org");
    testing.assertEqual(len($addrs), 2);
    testing.assertEqual($addrs[0], "93.184.216.34");
    testing.assertEqual($addrs[1], "2606:2800:220:1::1");
}

func testDnsAdlistFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "url": "https://example.org/hosts.txt",
        "match-count": "48211",
        "disabled": "false"
    };
    def a as DnsAdlist init dnsAdlistFromRow($row);
    testing.assertEqual($a.url, "https://example.org/hosts.txt");
    testing.assertEqual($a.matchCount, "48211");
    testing.assertFalse($a.disabled);
}
