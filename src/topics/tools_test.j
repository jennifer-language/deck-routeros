# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the tools topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testEnsureBandwidthParamsAcceptsBounds() {
    ensureBandwidthParams(1, "receive");
    ensureBandwidthParams(300, "transmit");
    ensureBandwidthParams(10, "both");
    testing.assertTrue(true);
}

func failBandwidthParamsZeroSeconds() {
    ensureBandwidthParams(0, "receive");
}

func testBandwidthParamsRejectZeroSeconds() {
    testing.assertThrows("failBandwidthParamsZeroSeconds", "routeros");
}

func failBandwidthParamsTooLong() {
    ensureBandwidthParams(301, "receive");
}

func testBandwidthParamsRejectTooLong() {
    testing.assertThrows("failBandwidthParamsTooLong", "routeros");
}

func failBandwidthParamsBadDirection() {
    ensureBandwidthParams(10, "sideways");
}

func testBandwidthParamsRejectBadDirection() {
    testing.assertThrows("failBandwidthParamsBadDirection", "routeros");
}

func testPingResultFromRowReachable() {
    def row as map of string to string init {
        "host": "1.1.1.1",
        "sent": "4",
        "received": "4",
        "packet-loss": "0",
        "min-rtt": "1ms52us",
        "avg-rtt": "2ms10us",
        "max-rtt": "4ms1us"
    };
    def p as PingResult init pingResultFromRow($row);
    testing.assertEqual($p.host, "1.1.1.1");
    testing.assertEqual($p.sent, 4);
    testing.assertEqual($p.received, 4);
    testing.assertEqual($p.packetLoss, 0);
    testing.assertEqual($p.minRtt, "1ms52us");
    testing.assertEqual($p.avgRtt, "2ms10us");
    testing.assertEqual($p.maxRtt, "4ms1us");
    testing.assertTrue($p.reachable);
}

func testPingResultFromRowAllLost() {
    def row as map of string to string init {
        "host": "10.99.99.99",
        "sent": "4",
        "received": "0",
        "packet-loss": "100"
    };
    def p as PingResult init pingResultFromRow($row);
    testing.assertEqual($p.received, 0);
    testing.assertEqual($p.packetLoss, 100);
    testing.assertFalse($p.reachable);
    testing.assertEqual($p.avgRtt, "");
}

func testPingResultFromMergedProgressRows() {
    def rows as list of map of string to string init [
        {"host": "1.1.1.1", "seq": "0", "time": "2ms"},
        {"host": "1.1.1.1", "seq": "1", "time": "3ms"},
        {"host": "1.1.1.1", "sent": "2", "received": "2", "packet-loss": "0",
         "min-rtt": "2ms", "avg-rtt": "2ms500us", "max-rtt": "3ms"}
    ];
    def p as PingResult init pingResultFromRow(mergeRows($rows));
    testing.assertEqual($p.sent, 2);
    testing.assertEqual($p.received, 2);
    testing.assertTrue($p.reachable);
}

func testBandwidthResultFromRow() {
    def row as map of string to string init {
        "status": "done testing",
        "direction": "receive",
        "tx-current": "0",
        "tx-total-average": "0",
        "rx-current": "94371840",
        "rx-total-average": "89128960",
        "lost-packets": "12"
    };
    def b as BandwidthResult init bandwidthResultFromRow($row);
    testing.assertEqual($b.status, "done testing");
    testing.assertEqual($b.direction, "receive");
    testing.assertEqual($b.rxCurrent, "94371840");
    testing.assertEqual($b.rxAverage, "89128960");
    testing.assertEqual($b.lostPackets, 12);
}

func testBandwidthResultFromSparseRow() {
    def row as map of string to string init {"status": "connecting"};
    def b as BandwidthResult init bandwidthResultFromRow($row);
    testing.assertEqual($b.status, "connecting");
    testing.assertEqual($b.rxAverage, "");
    testing.assertEqual($b.lostPackets, 0);
}

func testTracerouteHopFromRow() {
    def row as map of string to string init {
        "address": "10.0.0.1",
        "loss": "0%",
        "avg": "2.1ms",
        "status": ""
    };
    def h as TracerouteHop init tracerouteHopFromRow($row);
    testing.assertEqual($h.address, "10.0.0.1");
    testing.assertEqual($h.loss, "0%");
    testing.assertEqual($h.avgRtt, "2.1ms");
}

func testTracerouteHopFromTimeoutRow() {
    def row as map of string to string init {"loss": "100%", "status": "timeout"};
    def h as TracerouteHop init tracerouteHopFromRow($row);
    testing.assertEqual($h.address, "");
    testing.assertEqual($h.status, "timeout");
}

func testFetchResultFromRowOk() {
    def row as map of string to string init {
        "status": "finished",
        "downloaded": "1048576",
        "data": "203.0.113.5"
    };
    def r as FetchResult init fetchResultFromRow($row);
    testing.assertEqual($r.status, "finished");
    testing.assertTrue($r.ok);
    testing.assertEqual($r.downloaded, "1048576");
    testing.assertEqual($r.data, "203.0.113.5");
}

func testFetchResultFromRowFailed() {
    def row as map of string to string init {"status": "failed"};
    def r as FetchResult init fetchResultFromRow($row);
    testing.assertFalse($r.ok);
    testing.assertEqual($r.data, "");
}

func testEmailTlsWordModernPassesThrough() {
    testing.assertEqual(emailTlsWord(EMAIL_TLS_STARTTLS, "tls"), "starttls");
    testing.assertEqual(emailTlsWord(EMAIL_TLS_IMPLICIT, "tls"), "yes");
    testing.assertEqual(emailTlsWord(EMAIL_TLS_NONE, "tls"), "no");
}

# pre-7.12 routers spell the same three states differently
func testEmailTlsWordLegacyRemaps() {
    testing.assertEqual(emailTlsWord(EMAIL_TLS_STARTTLS, "start-tls"), "yes");
    testing.assertEqual(emailTlsWord(EMAIL_TLS_IMPLICIT, "start-tls"), "tls-only");
    testing.assertEqual(emailTlsWord(EMAIL_TLS_NONE, "start-tls"), "no");
}

func testModernTlsWordFoldsLegacyReadings() {
    testing.assertEqual(modernTlsWord("yes"), EMAIL_TLS_STARTTLS);
    testing.assertEqual(modernTlsWord("tls-only"), EMAIL_TLS_IMPLICIT);
    testing.assertEqual(modernTlsWord("no"), EMAIL_TLS_NONE);
    testing.assertEqual(modernTlsWord(""), EMAIL_TLS_NONE);
}

func testEmailTlsRoundTripsThroughLegacySpelling() {
    testing.assertEqual(modernTlsWord(emailTlsWord(EMAIL_TLS_STARTTLS, "start-tls")), EMAIL_TLS_STARTTLS);
    testing.assertEqual(modernTlsWord(emailTlsWord(EMAIL_TLS_IMPLICIT, "start-tls")), EMAIL_TLS_IMPLICIT);
    testing.assertEqual(modernTlsWord(emailTlsWord(EMAIL_TLS_NONE, "start-tls")), EMAIL_TLS_NONE);
}

func testEnsureEmailTlsAcceptsConstants() {
    ensureEmailTls(EMAIL_TLS_NONE);
    ensureEmailTls(EMAIL_TLS_STARTTLS);
    ensureEmailTls(EMAIL_TLS_IMPLICIT);
    testing.assertTrue(true);
}

func failEmailTlsUnknown() {
    ensureEmailTls("ssl");
}

func testEnsureEmailTlsRejectsUnknown() {
    testing.assertThrows("failEmailTlsUnknown", "routeros");
}
