# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the health topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testHealthSensorFromRow() {
    def row as map of string to string init {
        "name": "cpu-temperature",
        "value": "47",
        "type": "C"
    };
    def s as HealthSensor init healthSensorFromRow($row);
    testing.assertEqual($s.name, "cpu-temperature");
    testing.assertEqual($s.value, "47");
    testing.assertEqual($s.kind, "C");
}

func testHealthSensorFromSparseRow() {
    def row as map of string to string init {"name": "voltage", "value": "24.1"};
    def s as HealthSensor init healthSensorFromRow($row);
    testing.assertEqual($s.value, "24.1");
    testing.assertEqual($s.kind, "");
}
