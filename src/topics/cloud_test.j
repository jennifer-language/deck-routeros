# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the cloud topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testCloudFromRow() {
    def row as map of string to string init {
        "ddns-enabled": "true",
        "dns-name": "1234567890ab.sn.mynetname.net",
        "public-address": "203.0.113.5",
        "update-time": "true"
    };
    def st as CloudStatus init cloudFromRow($row);
    testing.assertTrue($st.ddnsEnabled);
    testing.assertEqual($st.dnsName, "1234567890ab.sn.mynetname.net");
    testing.assertEqual($st.publicAddress, "203.0.113.5");
}

func testCloudFromRowDisabled() {
    def row as map of string to string init {"ddns-enabled": "false"};
    def st as CloudStatus init cloudFromRow($row);
    testing.assertFalse($st.ddnsEnabled);
    testing.assertEqual($st.dnsName, "");
    testing.assertEqual($st.publicAddress, "");
}
