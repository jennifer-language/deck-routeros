# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the sms topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testSmsSettingsFromRow() {
    def row as map of string to string init {
        "receive-enabled": "yes",
        "port": "lte1",
        "channel": "0",
        "allowed-number": "+441632960123",
        "keep-max-sms": "50",
        "auto-erase": "no"
    };
    def s as SmsSettings init smsSettingsFromRow($row);
    testing.assertTrue($s.receiveEnabled);
    testing.assertEqual($s.port, "lte1");
    testing.assertEqual($s.allowedNumber, "+441632960123");
    testing.assertEqual($s.keepMaxSms, 50);
    testing.assertFalse($s.autoErase);
}

func testSmsSettingsFromSparseRow() {
    def row as map of string to string init {"receive-enabled": "false"};
    def s as SmsSettings init smsSettingsFromRow($row);
    testing.assertFalse($s.receiveEnabled);
    testing.assertEqual($s.port, "");
    testing.assertEqual($s.keepMaxSms, 0);
}

func testSmsMessageFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "phone": "+441632960123",
        "message": "gw1: uplink down",
        "timestamp": "aug/19/2026 08:14:22",
        "type": "normal"
    };
    def m as SmsMessage init smsMessageFromRow($row);
    testing.assertEqual($m.id, "*1");
    testing.assertEqual($m.phone, "+441632960123");
    testing.assertEqual($m.message, "gw1: uplink down");
    testing.assertEqual($m.kind, "normal");
}

func testPhoneNumberAcceptsCommonFormats() {
    ensurePhoneNumber("+441632960123");
    ensurePhoneNumber("0044 1632 960123");
    ensurePhoneNumber("(030) 12345-67");
    testing.assertTrue(true);
}

func failPhoneNumberEmpty() {
    ensurePhoneNumber("");
}

func testPhoneNumberRejectsEmpty() {
    testing.assertThrows("failPhoneNumberEmpty", "routeros");
}

func failPhoneNumberLetters() {
    ensurePhoneNumber("call-the-office");
}

func testPhoneNumberRejectsLetters() {
    testing.assertThrows("failPhoneNumberLetters", "routeros");
}

# punctuation alone parses character-by-character but carries no number
func failPhoneNumberDigitless() {
    ensurePhoneNumber("+- ()");
}

func testPhoneNumberRejectsDigitless() {
    testing.assertThrows("failPhoneNumberDigitless", "routeros");
}
