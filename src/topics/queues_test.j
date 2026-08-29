# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the queues topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testNormalizedRateKeepsCanonicalForms() {
    testing.assertEqual(normalizedRate("10M"), "10M");
    testing.assertEqual(normalizedRate("512k"), "512k");
    testing.assertEqual(normalizedRate("1G"), "1G");
    testing.assertEqual(normalizedRate("2500000"), "2500000");
    testing.assertEqual(normalizedRate("0"), "0");
}

func testNormalizedRateFixesCaseAndSpace() {
    testing.assertEqual(normalizedRate(" 10m "), "10M");
    testing.assertEqual(normalizedRate("512K"), "512k");
    testing.assertEqual(normalizedRate("1g"), "1G");
}

func failNormalizedRateEmpty() {
    normalizedRate("   ");
}

func testNormalizedRateRejectsEmpty() {
    testing.assertThrows("failNormalizedRateEmpty", "routeros");
}

func failNormalizedRateBadSuffix() {
    normalizedRate("10X");
}

func testNormalizedRateRejectsBadSuffix() {
    testing.assertThrows("failNormalizedRateBadSuffix", "routeros");
}

func failNormalizedRateSuffixOnly() {
    normalizedRate("M");
}

func testNormalizedRateRejectsSuffixOnly() {
    testing.assertThrows("failNormalizedRateSuffixOnly", "routeros");
}

func failNormalizedRateDoubleSuffix() {
    normalizedRate("10Mk");
}

func testNormalizedRateRejectsDoubleSuffix() {
    testing.assertThrows("failNormalizedRateDoubleSuffix", "routeros");
}

func failNormalizedRateDigitsAfterSuffix() {
    normalizedRate("10M5");
}

func testNormalizedRateRejectsDigitsAfterSuffix() {
    testing.assertThrows("failNormalizedRateDigitsAfterSuffix", "routeros");
}

func testRateHalvesSplitsPair() {
    def halves as list of string init rateHalves("10M/20M");
    testing.assertEqual($halves[0], "10M");
    testing.assertEqual($halves[1], "20M");
}

func testRateHalvesSingleValueCountsTwice() {
    def halves as list of string init rateHalves("5M");
    testing.assertEqual($halves[0], "5M");
    testing.assertEqual($halves[1], "5M");
}

func testRateHalvesEmptyStaysEmpty() {
    def halves as list of string init rateHalves("");
    testing.assertEqual($halves[0], "");
    testing.assertEqual($halves[1], "");
}

func testTargetKindClassifies() {
    testing.assertEqual(targetKind("192.168.88.0/24"), "cidr");
    testing.assertEqual(targetKind("192.168.88.50"), "address");
    testing.assertEqual(targetKind("ether1"), "name");
}

func failTargetKindBadCidr() {
    targetKind("192.168.88.0/99");
}

func testTargetKindRejectsBadCidr() {
    testing.assertThrows("failTargetKindBadCidr", "routeros");
}

func failTargetKindSpacedName() {
    targetKind("my queue target");
}

func testTargetKindRejectsSpacedName() {
    testing.assertThrows("failTargetKindSpacedName", "routeros");
}

func testSimpleQueueFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "guest-wifi",
        "target": "192.168.90.0/24",
        "max-limit": "5M/20M",
        "dynamic": "false",
        "disabled": "false",
        "comment": "guests"
    };
    def q as SimpleQueue init simpleQueueFromRow($row);
    testing.assertEqual($q.id, "*1");
    testing.assertEqual($q.name, "guest-wifi");
    testing.assertEqual($q.target, "192.168.90.0/24");
    testing.assertEqual($q.maxUpload, "5M");
    testing.assertEqual($q.maxDownload, "20M");
    testing.assertFalse($q.dynamic);
    testing.assertFalse($q.disabled);
    testing.assertEqual($q.comment, "guests");
}

func testSimpleQueueFromSparseRow() {
    def row as map of string to string init {".id": "*2", "name": "q", "target": "ether1"};
    def q as SimpleQueue init simpleQueueFromRow($row);
    testing.assertEqual($q.maxUpload, "");
    testing.assertEqual($q.maxDownload, "");
    testing.assertFalse($q.dynamic);
    testing.assertEqual($q.comment, "");
}

func testTreeQueueFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "qosupvoip",
        "parent": "qosup",
        "packet-mark": "voip",
        "limit-at": "5M",
        "max-limit": "38M",
        "priority": "1",
        "disabled": "false",
        "comment": "voice first"
    };
    def t as TreeQueue init treeQueueFromRow($row);
    testing.assertEqual($t.id, "*1");
    testing.assertEqual($t.name, "qosupvoip");
    testing.assertEqual($t.parent, "qosup");
    testing.assertEqual($t.packetMark, "voip");
    testing.assertEqual($t.limitAt, "5M");
    testing.assertEqual($t.maxLimit, "38M");
    testing.assertEqual($t.priority, 1);
    testing.assertFalse($t.disabled);
    testing.assertEqual($t.comment, "voice first");
}

func testTreeQueueFromRootRow() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "qosup",
        "parent": "pppoewan",
        "max-limit": "38M"
    };
    def t as TreeQueue init treeQueueFromRow($row);
    testing.assertEqual($t.packetMark, "");
    testing.assertEqual($t.limitAt, "");
    testing.assertEqual($t.priority, 0);
}

func testEnsureTreePriorityBounds() {
    ensureTreePriority(1);
    ensureTreePriority(8);
    testing.assertTrue(true);
}

func failTreePriorityZero() {
    ensureTreePriority(0);
}

func testEnsureTreePriorityRejectsZero() {
    testing.assertThrows("failTreePriorityZero", "routeros");
}

func failTreePriorityNine() {
    ensureTreePriority(9);
}

func testEnsureTreePriorityRejectsNine() {
    testing.assertThrows("failTreePriorityNine", "routeros");
}

func testTreeQueueFamilyChildrenFirst() {
    def rows as list of map of string to string init [
        {".id": "*1", "name": "qosup", "parent": "pppoewan"},
        {".id": "*2", "name": "qosupvoip", "parent": "qosup"},
        {".id": "*3", "name": "qosupbulk", "parent": "qosup"},
        {".id": "*4", "name": "qosupbulklow", "parent": "qosupbulk"},
        {".id": "*5", "name": "other", "parent": "brlan"}
    ];
    def ids as list of string init treeQueueFamily($rows, "qosup");
    testing.assertEqual(len($ids), 4);
    testing.assertEqual($ids[3], "*1");
    testing.assertEqual($ids[0], "*4");
}

func testTreeQueueFamilySingleNode() {
    def rows as list of map of string to string init [
        {".id": "*1", "name": "qosup", "parent": "pppoewan"}
    ];
    def ids as list of string init treeQueueFamily($rows, "qosup");
    testing.assertEqual(len($ids), 1);
    testing.assertEqual($ids[0], "*1");
}

func testTreeQueueFamilyUnknownNameIsEmpty() {
    def rows as list of map of string to string init [
        {".id": "*1", "name": "qosup", "parent": "pppoewan"}
    ];
    testing.assertEqual(len(treeQueueFamily($rows, "nosuch")), 0);
}
