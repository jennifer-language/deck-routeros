# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the upnp topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testUpnpFromRow() {
    def row as map of string to string init {"enabled": "true"};
    def s as UpnpSettings init upnpFromRow($row);
    testing.assertTrue($s.enabled);
}

func testUpnpFromRowDisabled() {
    def row as map of string to string init {"enabled": "false"};
    def s as UpnpSettings init upnpFromRow($row);
    testing.assertFalse($s.enabled);
}

func testUpnpInterfaceFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "interface": "ether1",
        "type": "external",
        "disabled": "false"
    };
    def ui as UpnpInterface init upnpInterfaceFromRow($row);
    testing.assertEqual($ui.interfaceName, "ether1");
    testing.assertEqual($ui.role, "external");
    testing.assertFalse($ui.disabled);
}
