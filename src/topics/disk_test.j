# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the disk topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testDiskFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "usb1",
        "disk": "SanDisk Ultra",
        "type": "hardware",
        "fs": "ext4",
        "size": "64023257088",
        "free": "51200000000",
        "slot": "usb1"
    };
    def d as Disk init diskFromRow($row);
    testing.assertEqual($d.name, "usb1");
    testing.assertEqual($d.model, "SanDisk Ultra");
    testing.assertEqual($d.kind, "hardware");
    testing.assertEqual($d.fs, "ext4");
    testing.assertEqual($d.sizeBytes, 64023257088);
    testing.assertEqual($d.freeBytes, 51200000000);
    testing.assertEqual($d.slot, "usb1");
}

func testDiskFromSparseRow() {
    def row as map of string to string init {".id": "*2", "name": "nvme1", "disk": "unformatted"};
    def d as Disk init diskFromRow($row);
    testing.assertEqual($d.fs, "");
    testing.assertEqual($d.sizeBytes, 0);
    testing.assertEqual($d.freeBytes, 0);
}

func testDiskFromRowNameFallsBackToSlot() {
    # RouterOS 7.21.5 leaves "name" empty on plain USB storage.
    def row as map of string to string init {
        ".id": "*1",
        "type": "hardware",
        "fs": "-",
        "size": "31037849600",
        "slot": "usb1"
    };
    def d as Disk init diskFromRow($row);
    testing.assertEqual($d.name, "usb1");
    testing.assertEqual($d.slot, "usb1");
}

func testDiskRowMatchingPrefersName() {
    def rows as list of map of string to string init [
        {".id": "*1", "name": "usb1", "slot": "usb2"},
        {".id": "*2", "name": "other", "slot": "usb1"}
    ];
    def row as map of string to string init diskRowMatching($rows, "usb1");
    testing.assertEqual(rowValue($row, ".id"), "*1");
}

func testDiskRowMatchingFallsBackToSlot() {
    def rows as list of map of string to string init [
        {".id": "*1", "slot": "usb1"},
        {".id": "*2", "slot": "usb1-part1"}
    ];
    testing.assertEqual(rowValue(diskRowMatching($rows, "usb1-part1"), ".id"), "*2");
}

func testDiskRowMatchingMissIsEmpty() {
    def rows as list of map of string to string init [{".id": "*1", "slot": "usb1"}];
    testing.assertEqual(len(diskRowMatching($rows, "nvme1")), 0);
}

func testIsUnknownCommandRecognisesTheTrap() {
    testing.assertTrue(isUnknownCommand("mikrotik", "!trap: no such command"));
    testing.assertTrue(isUnknownCommand("mikrotik", "No such command or directory"));
}

func testIsUnknownCommandKeepsRealFailures() {
    testing.assertFalse(isUnknownCommand("mikrotik", "!trap: device is busy"));
    testing.assertFalse(isUnknownCommand("routeros", "no such command"));
}
