# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the radius topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testRadiusServerFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "address": "10.0.9.20",
        "service": "login,ppp",
        "timeout": "300ms",
        "disabled": "false",
        "comment": "AD"
    };
    def s as RadiusServer init radiusServerFromRow($row);
    testing.assertEqual($s.address, "10.0.9.20");
    testing.assertEqual($s.services, "login,ppp");
    testing.assertEqual($s.timeout, "300ms");
    testing.assertFalse($s.disabled);
    testing.assertEqual($s.comment, "AD");
}

func testNormalizedRadiusServicesForms() {
    testing.assertEqual(normalizedRadiusServices("login"), "login");
    testing.assertEqual(normalizedRadiusServices(" login , ppp , hotspot "), "login,ppp,hotspot");
}

func failRadiusServiceUnknown() {
    normalizedRadiusServices("login,telepathy");
}

func testNormalizedRadiusServicesRejectsUnknown() {
    testing.assertThrows("failRadiusServiceUnknown", "routeros");
}

func failRadiusServiceEmptyEntry() {
    normalizedRadiusServices("login,,ppp");
}

func testNormalizedRadiusServicesRejectsEmptyEntry() {
    testing.assertThrows("failRadiusServiceEmptyEntry", "routeros");
}
