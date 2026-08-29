# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the users topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func failNotSelfSameAccount() {
    ensureNotSelf("admin", "admin", "remove");
}

func testEnsureNotSelfRefusesOwnAccount() {
    testing.assertThrows("failNotSelfSameAccount", "routeros");
}

func testEnsureNotSelfAllowsOtherAccounts() {
    ensureNotSelf("admin", "monitoring", "remove");
    testing.assertTrue(true);
}

func failUserPasswordEmpty() {
    ensureUserPassword("   ");
}

func testEnsureUserPasswordRejectsEmpty() {
    testing.assertThrows("failUserPasswordEmpty", "routeros");
}

func testNormalizedUserAddressForms() {
    testing.assertEqual(normalizedUserAddress("10.0.9.1"), "10.0.9.1");
    testing.assertEqual(normalizedUserAddress("10.0.9.0/24"), "10.0.9.0/24");
    testing.assertEqual(
        normalizedUserAddress(" 10.0.9.0/24 , 192.168.88.10 "),
        "10.0.9.0/24,192.168.88.10");
}

func failUserAddressHostname() {
    normalizedUserAddress("admin.example.org");
}

func testNormalizedUserAddressRejectsHostname() {
    testing.assertThrows("failUserAddressHostname", "routeros");
}

func failUserAddressEmptyEntry() {
    normalizedUserAddress("10.0.9.1,,10.0.9.2");
}

func testNormalizedUserAddressRejectsEmptyEntry() {
    testing.assertThrows("failUserAddressEmptyEntry", "routeros");
}

func testUserFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "monitoring",
        "group": "read",
        "address": "10.0.9.0/24",
        "last-logged-in": "2026-07-24 09:12:00",
        "disabled": "false",
        "comment": "grafana poller"
    };
    def u as User init userFromRow($row);
    testing.assertEqual($u.id, "*1");
    testing.assertEqual($u.name, "monitoring");
    testing.assertEqual($u.group, "read");
    testing.assertEqual($u.address, "10.0.9.0/24");
    testing.assertEqual($u.lastLoggedIn, "2026-07-24 09:12:00");
    testing.assertFalse($u.disabled);
    testing.assertEqual($u.comment, "grafana poller");
}

func testUserFromSparseRow() {
    def row as map of string to string init {".id": "*2", "name": "backup", "group": "full"};
    def u as User init userFromRow($row);
    testing.assertEqual($u.address, "");
    testing.assertEqual($u.lastLoggedIn, "");
    testing.assertFalse($u.disabled);
    testing.assertEqual($u.comment, "");
}

func testUserGroupFromRow() {
    def row as map of string to string init {
        ".id": "*3",
        "name": "read",
        "policy": "local,telnet,ssh,read,test,winbox,api,!write"
    };
    def g as UserGroup init userGroupFromRow($row);
    testing.assertEqual($g.id, "*3");
    testing.assertEqual($g.name, "read");
    testing.assertEqual($g.policy, "local,telnet,ssh,read,test,winbox,api,!write");
}

func testUserSessionFromRow() {
    def row as map of string to string init {
        "name": "admin",
        "address": "10.0.9.5",
        "via": "api",
        "when": "2026-07-24 15:30:11"
    };
    def s as UserSession init userSessionFromRow($row);
    testing.assertEqual($s.name, "admin");
    testing.assertEqual($s.address, "10.0.9.5");
    testing.assertEqual($s.via, "api");
    testing.assertEqual($s.when, "2026-07-24 15:30:11");
}

func testUserSessionFromConsoleRow() {
    def row as map of string to string init {"name": "admin", "via": "console"};
    def s as UserSession init userSessionFromRow($row);
    testing.assertEqual($s.address, "");
    testing.assertEqual($s.via, "console");
}
