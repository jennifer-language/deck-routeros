# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the routing topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testEnsureDistanceAcceptsBounds() {
    ensureDistance(1);
    ensureDistance(255);
    testing.assertTrue(true);
}

func failEnsureDistanceZero() {
    ensureDistance(0);
}

func testEnsureDistanceRejectsZero() {
    testing.assertThrows("failEnsureDistanceZero", "routeros");
}

func failEnsureDistanceTooBig() {
    ensureDistance(256);
}

func testEnsureDistanceRejectsTooBig() {
    testing.assertThrows("failEnsureDistanceTooBig", "routeros");
}

func testStaticRouteRowSkipsDynamic() {
    def rows as list of map of string to string init [
        {".id": "*1", "dst-address": "10.20.0.0/16", "dynamic": "true"},
        {".id": "*2", "dst-address": "10.20.0.0/16", "dynamic": "false"}
    ];
    def row as map of string to string init staticRouteRow($rows, "10.20.0.0/16");
    testing.assertEqual(rowValue($row, ".id"), "*2");
}

func testStaticRouteRowOnlyDynamicIsMiss() {
    def rows as list of map of string to string init [
        {".id": "*1", "dst-address": "192.168.88.0/24", "dynamic": "true"}
    ];
    def row as map of string to string init staticRouteRow($rows, "192.168.88.0/24");
    testing.assertEqual(len($row), 0);
}

func testStaticRouteRowUnknownDestinationIsMiss() {
    def rows as list of map of string to string init [
        {".id": "*1", "dst-address": "10.20.0.0/16", "dynamic": "false"}
    ];
    def row as map of string to string init staticRouteRow($rows, "10.30.0.0/16");
    testing.assertEqual(len($row), 0);
}

func testStaticRouteRowMissingDynamicKeyIsStatic() {
    def rows as list of map of string to string init [
        {".id": "*1", "dst-address": "0.0.0.0/0"}
    ];
    def row as map of string to string init staticRouteRow($rows, "0.0.0.0/0");
    testing.assertEqual(rowValue($row, ".id"), "*1");
}

func testRouteFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "dst-address": "0.0.0.0/0",
        "gateway": "192.168.88.254",
        "distance": "1",
        "routing-table": "main",
        "active": "true",
        "dynamic": "false",
        "disabled": "false",
        "comment": "uplink"
    };
    def r as Route init routeFromRow($row);
    testing.assertEqual($r.id, "*1");
    testing.assertEqual($r.dstAddress, "0.0.0.0/0");
    testing.assertEqual($r.gateway, "192.168.88.254");
    testing.assertEqual($r.distance, "1");
    testing.assertEqual($r.routingTable, "main");
    testing.assertTrue($r.active);
    testing.assertFalse($r.dynamic);
    testing.assertFalse($r.disabled);
    testing.assertEqual($r.comment, "uplink");
}

func testRouteFromRowConnectedRoute() {
    def row as map of string to string init {
        ".id": "*2",
        "dst-address": "192.168.88.0/24",
        "gateway": "brlan",
        "dynamic": "true",
        "active": "true"
    };
    def r as Route init routeFromRow($row);
    testing.assertEqual($r.gateway, "brlan");
    testing.assertTrue($r.dynamic);
    testing.assertEqual($r.distance, "");
    testing.assertEqual($r.comment, "");
}

func testRoutingRuleFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "src-address": "10.30.0.0/24",
        "action": "lookup",
        "table": "backupisp",
        "disabled": "false",
        "comment": "guests via backup"
    };
    def rule as RoutingRule init routingRuleFromRow($row);
    testing.assertEqual($rule.id, "*1");
    testing.assertEqual($rule.srcAddress, "10.30.0.0/24");
    testing.assertEqual($rule.action, "lookup");
    testing.assertEqual($rule.table, "backupisp");
    testing.assertFalse($rule.disabled);
    testing.assertEqual($rule.comment, "guests via backup");
}

func testRoutingRuleFromSparseRow() {
    def row as map of string to string init {
        ".id": "*2",
        "action": "lookup-only-in-table",
        "table": "main"
    };
    def rule as RoutingRule init routingRuleFromRow($row);
    testing.assertEqual($rule.srcAddress, "");
    testing.assertEqual($rule.dstAddress, "");
    testing.assertEqual($rule.interfaceName, "");
    testing.assertEqual($rule.action, "lookup-only-in-table");
}

func testFindRoutingRuleRowMatchesBoth() {
    def rows as list of map of string to string init [
        {".id": "*1", "src-address": "10.30.0.0/24", "table": "backupisp"},
        {".id": "*2", "src-address": "10.30.0.0/24", "table": "main"},
        {".id": "*3", "src-address": "10.40.0.0/24", "table": "backupisp"}
    ];
    def row as map of string to string init
        findRoutingRuleRow($rows, "10.30.0.0/24", "backupisp");
    testing.assertEqual(rowValue($row, ".id"), "*1");
}

func testFindRoutingRuleRowMissOnTableMismatch() {
    def rows as list of map of string to string init [
        {".id": "*1", "src-address": "10.30.0.0/24", "table": "backupisp"}
    ];
    def row as map of string to string init
        findRoutingRuleRow($rows, "10.30.0.0/24", "otherisp");
    testing.assertEqual(len($row), 0);
}
