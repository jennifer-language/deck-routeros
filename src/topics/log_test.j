# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the log topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testLogHasTopicFindsExactWord() {
    testing.assertTrue(logHasTopic("system,info", "info"));
    testing.assertTrue(logHasTopic("firewall", "firewall"));
    testing.assertTrue(logHasTopic("system, info", "info"));
}

func testLogHasTopicNoPartialMatch() {
    testing.assertFalse(logHasTopic("system,info", "inf"));
    testing.assertFalse(logHasTopic("firewalls", "firewall"));
    testing.assertFalse(logHasTopic("", "info"));
}

func testIsProblemTopics() {
    testing.assertTrue(isProblemTopics("system,error"));
    testing.assertTrue(isProblemTopics("critical"));
    testing.assertFalse(isProblemTopics("system,info"));
    testing.assertFalse(isProblemTopics("warning"));
}

func testNormalizedLogTopicsForms() {
    testing.assertEqual(normalizedLogTopics("firewall"), "firewall");
    testing.assertEqual(normalizedLogTopics(" info , !dns "), "info,!dns");
    testing.assertEqual(
        normalizedLogTopics("info,warning,error,critical"),
        "info,warning,error,critical");
}

func failLogTopicsEmptyEntry() {
    normalizedLogTopics("info,,error");
}

func testNormalizedLogTopicsRejectsEmptyEntry() {
    testing.assertThrows("failLogTopicsEmptyEntry", "routeros");
}

func failLogTopicsSpacedWord() {
    normalizedLogTopics("fire wall");
}

func testNormalizedLogTopicsRejectsSpacedWord() {
    testing.assertThrows("failLogTopicsSpacedWord", "routeros");
}

func testFindLoggingRowMatchesBoth() {
    def rows as list of map of string to string init [
        {".id": "*1", "topics": "info", "action": "memory"},
        {".id": "*2", "topics": "firewall", "action": "disk"},
        {".id": "*3", "topics": "firewall", "action": "memory"}
    ];
    def row as map of string to string init findLoggingRow($rows, "firewall", "disk");
    testing.assertEqual(rowValue($row, ".id"), "*2");
}

func testFindLoggingRowMissesOnActionMismatch() {
    def rows as list of map of string to string init [
        {".id": "*1", "topics": "firewall", "action": "memory"}
    ];
    def row as map of string to string init findLoggingRow($rows, "firewall", "remote");
    testing.assertEqual(len($row), 0);
}

func testLastEntriesTakesTail() {
    def entries as list of LogEntry init [
        LogEntry{id: "*1", time: "10:00:00", topics: "system,info", message: "one"},
        LogEntry{id: "*2", time: "10:01:00", topics: "system,info", message: "two"},
        LogEntry{id: "*3", time: "10:02:00", topics: "system,info", message: "three"}
    ];
    def tail as list of LogEntry init lastEntries($entries, 2);
    testing.assertEqual(len($tail), 2);
    testing.assertEqual($tail[0].message, "two");
    testing.assertEqual($tail[1].message, "three");
}

func testLastEntriesShortListStaysWhole() {
    def entries as list of LogEntry init [
        LogEntry{id: "*1", time: "10:00:00", topics: "system,info", message: "one"}
    ];
    def tail as list of LogEntry init lastEntries($entries, 10);
    testing.assertEqual(len($tail), 1);
}

func testLogEntryFromRow() {
    def row as map of string to string init {
        ".id": "*42",
        "time": "15:33:02",
        "topics": "system,info",
        "message": "user admin logged in from 10.0.9.5 via api"
    };
    def entry as LogEntry init logEntryFromRow($row);
    testing.assertEqual($entry.id, "*42");
    testing.assertEqual($entry.time, "15:33:02");
    testing.assertEqual($entry.topics, "system,info");
    testing.assertEqual($entry.message, "user admin logged in from 10.0.9.5 via api");
}

func testLogEntryFromSparseRow() {
    def row as map of string to string init {"message": "boot"};
    def entry as LogEntry init logEntryFromRow($row);
    testing.assertEqual($entry.time, "");
    testing.assertEqual($entry.topics, "");
    testing.assertEqual($entry.message, "boot");
}

func testLoggingRuleFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "topics": "info,!dns",
        "action": "remote",
        "prefix": "gw",
        "disabled": "false"
    };
    def rule as LoggingRule init loggingRuleFromRow($row);
    testing.assertEqual($rule.id, "*1");
    testing.assertEqual($rule.topics, "info,!dns");
    testing.assertEqual($rule.action, "remote");
    testing.assertEqual($rule.prefix, "gw");
    testing.assertFalse($rule.disabled);
}

func testLoggingRuleFromSparseRow() {
    def row as map of string to string init {".id": "*2", "topics": "critical", "action": "echo"};
    def rule as LoggingRule init loggingRuleFromRow($row);
    testing.assertEqual($rule.prefix, "");
    testing.assertFalse($rule.disabled);
}
