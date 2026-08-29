# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the clock topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testClockFromRow() {
    def row as map of string to string init {
        "time": "15:33:02",
        "date": "2026-07-24",
        "time-zone-name": "Europe/Berlin",
        "time-zone-autodetect": "false",
        "gmt-offset": "+02:00"
    };
    def ck as Clock init clockFromRow($row);
    testing.assertEqual($ck.time, "15:33:02");
    testing.assertEqual($ck.date, "2026-07-24");
    testing.assertEqual($ck.timezone, "Europe/Berlin");
    testing.assertFalse($ck.autodetect);
    testing.assertEqual($ck.gmtOffset, "+02:00");
}

func testNtpFromRowSynced() {
    def row as map of string to string init {
        "enabled": "true",
        "servers": "pool.ntp.org",
        "status": "synchronized"
    };
    def st as NtpStatus init ntpFromRow($row);
    testing.assertTrue($st.enabled);
    testing.assertEqual($st.servers, "pool.ntp.org");
    testing.assertTrue($st.synced);
}

func testNtpFromRowNotSynced() {
    def row as map of string to string init {
        "enabled": "true",
        "servers": "10.0.0.1",
        "status": "waiting"
    };
    def st as NtpStatus init ntpFromRow($row);
    testing.assertFalse($st.synced);
    testing.assertEqual($st.status, "waiting");
}

func testNormalizedNtpServersForms() {
    testing.assertEqual(normalizedNtpServers("pool.ntp.org"), "pool.ntp.org");
    testing.assertEqual(
        normalizedNtpServers(" 0.pool.ntp.org , 1.pool.ntp.org "),
        "0.pool.ntp.org,1.pool.ntp.org");
}

func failNtpServersEmptyEntry() {
    normalizedNtpServers("pool.ntp.org,,10.0.0.1");
}

func testNormalizedNtpServersRejectsEmptyEntry() {
    testing.assertThrows("failNtpServersEmptyEntry", "routeros");
}

func failNtpServersSpacedEntry() {
    normalizedNtpServers("pool ntp org");
}

func testNormalizedNtpServersRejectsSpacedEntry() {
    testing.assertThrows("failNtpServersSpacedEntry", "routeros");
}
