# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the scheduler topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testEnsureClockTimeAcceptsForms() {
    ensureClockTime("03:00:00");
    ensureClockTime("23:59:59");
    ensureClockTime("0:5:9");
    testing.assertTrue(true);
}

func failEnsureClockTimeBadHour() {
    ensureClockTime("24:00:00");
}

func testEnsureClockTimeRejectsBadHour() {
    testing.assertThrows("failEnsureClockTimeBadHour", "routeros");
}

func failEnsureClockTimeBadMinute() {
    ensureClockTime("12:60:00");
}

func testEnsureClockTimeRejectsBadMinute() {
    testing.assertThrows("failEnsureClockTimeBadMinute", "routeros");
}

func failEnsureClockTimeTwoParts() {
    ensureClockTime("12:00");
}

func testEnsureClockTimeRejectsTwoParts() {
    testing.assertThrows("failEnsureClockTimeTwoParts", "routeros");
}

func failEnsureClockTimeLetters() {
    ensureClockTime("ab:cd:ef");
}

func testEnsureClockTimeRejectsLetters() {
    testing.assertThrows("failEnsureClockTimeLetters", "routeros");
}

func testEnsureSchedulerIntervalAcceptsForms() {
    ensureSchedulerInterval("30s");
    ensureSchedulerInterval("10m");
    ensureSchedulerInterval("2h");
    ensureSchedulerInterval("1d");
    ensureSchedulerInterval("1w");
    ensureSchedulerInterval("1d12h");
    ensureSchedulerInterval("00:30:00");
    ensureSchedulerInterval("90");
    ensureSchedulerInterval("0");
    testing.assertTrue(true);
}

func failEnsureSchedulerIntervalWord() {
    ensureSchedulerInterval("daily");
}

func testEnsureSchedulerIntervalRejectsWord() {
    testing.assertThrows("failEnsureSchedulerIntervalWord", "routeros");
}

func failEnsureSchedulerIntervalBadSuffix() {
    ensureSchedulerInterval("5x");
}

func testEnsureSchedulerIntervalRejectsBadSuffix() {
    testing.assertThrows("failEnsureSchedulerIntervalBadSuffix", "routeros");
}

func failEnsureSchedulerIntervalSuffixFirst() {
    ensureSchedulerInterval("d5");
}

func testEnsureSchedulerIntervalRejectsSuffixFirst() {
    testing.assertThrows("failEnsureSchedulerIntervalSuffixFirst", "routeros");
}

func failEnsureScriptSourceEmpty() {
    ensureScriptSource("   ");
}

func testEnsureScriptSourceRejectsEmpty() {
    testing.assertThrows("failEnsureScriptSourceEmpty", "routeros");
}

func testScheduledTaskFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "nightly-backup",
        "start-time": "03:00:00",
        "start-date": "2026-07-24",
        "interval": "1d",
        "on-event": "/system backup save name=nightly",
        "next-run": "2026-07-25 03:00:00",
        "run-count": "17",
        "disabled": "false",
        "comment": "keep a backup"
    };
    def t as ScheduledTask init scheduledTaskFromRow($row);
    testing.assertEqual($t.id, "*1");
    testing.assertEqual($t.name, "nightly-backup");
    testing.assertEqual($t.startTime, "03:00:00");
    testing.assertEqual($t.startDate, "2026-07-24");
    testing.assertEqual($t.interval, "1d");
    testing.assertEqual($t.onEvent, "/system backup save name=nightly");
    testing.assertEqual($t.nextRun, "2026-07-25 03:00:00");
    testing.assertEqual($t.runCount, 17);
    testing.assertFalse($t.disabled);
    testing.assertEqual($t.comment, "keep a backup");
}

func testScheduledTaskFromSparseRow() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "boot-task",
        "start-time": "startup",
        "interval": "0"
    };
    def t as ScheduledTask init scheduledTaskFromRow($row);
    testing.assertEqual($t.startTime, "startup");
    testing.assertEqual($t.interval, "0");
    testing.assertEqual($t.runCount, 0);
    testing.assertFalse($t.disabled);
    testing.assertEqual($t.onEvent, "");
}
