# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

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
