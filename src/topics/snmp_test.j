# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the snmp topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testSnmpFromRow() {
    def row as map of string to string init {
        "enabled": "true",
        "contact": "noc@example.org",
        "location": "rack 3, office Berlin"
    };
    def st as SnmpSettings init snmpFromRow($row);
    testing.assertTrue($st.enabled);
    testing.assertEqual($st.contact, "noc@example.org");
    testing.assertEqual($st.location, "rack 3, office Berlin");
}

func testSnmpFromSparseRow() {
    def row as map of string to string init {"enabled": "false"};
    def st as SnmpSettings init snmpFromRow($row);
    testing.assertFalse($st.enabled);
    testing.assertEqual($st.contact, "");
}

func testSnmpCommunityFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "mon",
        "addresses": "10.0.9.0/24",
        "read-access": "true",
        "write-access": "false",
        "disabled": "false"
    };
    def com as SnmpCommunity init snmpCommunityFromRow($row);
    testing.assertEqual($com.id, "*1");
    testing.assertEqual($com.name, "mon");
    testing.assertEqual($com.addresses, "10.0.9.0/24");
    testing.assertTrue($com.readAccess);
    testing.assertFalse($com.writeAccess);
    testing.assertFalse($com.disabled);
}

func testSnmpCommunityFromRowDefaultPublic() {
    def row as map of string to string init {
        ".id": "*2",
        "name": "public",
        "read-access": "true"
    };
    def com as SnmpCommunity init snmpCommunityFromRow($row);
    testing.assertEqual($com.name, "public");
    testing.assertEqual($com.addresses, "");
    testing.assertFalse($com.writeAccess);
}
