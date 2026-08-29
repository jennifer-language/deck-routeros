# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the core topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testApiPathAddsLeadingSlash() {
    testing.assertEqual(apiPath("interface"), "/interface");
}

func testApiPathKeepsGoodPath() {
    testing.assertEqual(apiPath("/ip/firewall/filter"), "/ip/firewall/filter");
}

func testApiPathStripsTrailingSlashes() {
    testing.assertEqual(apiPath("/interface/bridge//"), "/interface/bridge");
}

func testApiPathTrimsWhitespace() {
    testing.assertEqual(apiPath("  /interface  "), "/interface");
}

func failApiPathEmpty() {
    apiPath("   ");
}

func testApiPathRejectsEmpty() {
    testing.assertThrows("failApiPathEmpty", "routeros");
}

func failApiPathRoot() {
    apiPath("/");
}

func testApiPathRejectsRoot() {
    testing.assertThrows("failApiPathRoot", "routeros");
}

func testBoolWord() {
    testing.assertEqual(boolWord(true), "yes");
    testing.assertEqual(boolWord(false), "no");
}

func testRowValueReadsPresentKey() {
    def row as map of string to string init {"name": "ether1"};
    testing.assertEqual(rowValue($row, "name"), "ether1");
}

func testRowValueDefaultsMissingKey() {
    def row as map of string to string init {"name": "ether1"};
    testing.assertEqual(rowValue($row, "comment"), "");
}

func testRowBoolAcceptsBothSpellings() {
    def row as map of string to string init {"a": "true", "b": "yes", "c": "false", "d": "no"};
    testing.assertTrue(rowBool($row, "a"));
    testing.assertTrue(rowBool($row, "b"));
    testing.assertFalse(rowBool($row, "c"));
    testing.assertFalse(rowBool($row, "d"));
}

func testRowBoolMissingKeyIsFalse() {
    def row as map of string to string init {"name": "ether1"};
    testing.assertFalse(rowBool($row, "running"));
}

func testFindRowByFieldFindsMatch() {
    def rows as list of map of string to string init [
        {".id": "*1", "name": "ether1"},
        {".id": "*2", "name": "ether2"}
    ];
    def row as map of string to string init findRowByField($rows, "name", "ether2");
    testing.assertEqual(rowValue($row, ".id"), "*2");
}

func testFindRowByFieldReturnsFirstMatch() {
    def rows as list of map of string to string init [
        {".id": "*1", "bridge": "brlan"},
        {".id": "*2", "bridge": "brlan"}
    ];
    def row as map of string to string init findRowByField($rows, "bridge", "brlan");
    testing.assertEqual(rowValue($row, ".id"), "*1");
}

func testFindRowByFieldMissReturnsEmptyMap() {
    def rows as list of map of string to string init [{".id": "*1", "name": "ether1"}];
    def row as map of string to string init findRowByField($rows, "name", "ether9");
    testing.assertEqual(len($row), 0);
}

func failEnsureNameEmpty() {
    ensureName("   ", "bridge");
}

func testEnsureNameRejectsEmpty() {
    testing.assertThrows("failEnsureNameEmpty", "routeros");
}

func failEnsureNameSpaces() {
    ensureName("br lan", "bridge");
}

func testEnsureNameRejectsSpaces() {
    testing.assertThrows("failEnsureNameSpaces", "routeros");
}

func testEnsureNameAcceptsPlainName() {
    ensureName("brlan", "bridge");
    testing.assertTrue(true);
}

func failEnsureIdEmpty() {
    ensureId("");
}

func testEnsureIdRejectsEmpty() {
    testing.assertThrows("failEnsureIdEmpty", "routeros");
}

func failEnsurePortZero() {
    ensurePort(0);
}

func testEnsurePortRejectsZero() {
    testing.assertThrows("failEnsurePortZero", "routeros");
}

func failEnsurePortTooBig() {
    ensurePort(65536);
}

func testEnsurePortRejectsTooBig() {
    testing.assertThrows("failEnsurePortTooBig", "routeros");
}

func testEnsurePortAcceptsBounds() {
    ensurePort(1);
    ensurePort(65535);
    testing.assertTrue(true);
}

func testEnsurePortSpecAcceptsForms() {
    ensurePortSpec("80");
    ensurePortSpec("80,443");
    ensurePortSpec("8000-8100");
    testing.assertTrue(true);
}

func failEnsurePortSpecLetters() {
    ensurePortSpec("80a");
}

func testEnsurePortSpecRejectsLetters() {
    testing.assertThrows("failEnsurePortSpecLetters", "routeros");
}

func failEnsurePortSpecEmpty() {
    ensurePortSpec("");
}

func testEnsurePortSpecRejectsEmpty() {
    testing.assertThrows("failEnsurePortSpecEmpty", "routeros");
}

func testMergeRowsLaterRowsWin() {
    def rows as list of map of string to string init [
        {"status": "checking for updates"},
        {"status": "downloading changelog", "channel": "stable"},
        {"status": "finished", "installed-version": "7.15.2", "latest-version": "7.16"}
    ];
    def merged as map of string to string init mergeRows($rows);
    testing.assertEqual($merged["status"], "finished");
    testing.assertEqual($merged["channel"], "stable");
    testing.assertEqual($merged["installed-version"], "7.15.2");
    testing.assertEqual($merged["latest-version"], "7.16");
    testing.assertEqual(len($merged), 4);
}

func testMergeRowsEmptyInput() {
    def rows as list of map of string to string init [];
    def merged as map of string to string init mergeRows($rows);
    testing.assertEqual(len($merged), 0);
}

func testEnsureIpAddressAcceptsBothVersions() {
    ensureIpAddress("192.168.88.1");
    ensureIpAddress("2001:db8::1");
    ensureIpAddress("  10.0.0.1  ");
    testing.assertTrue(true);
}

func failEnsureIpAddressWords() {
    ensureIpAddress("not-an-ip");
}

func testEnsureIpAddressRejectsWords() {
    testing.assertThrows("failEnsureIpAddressWords", "routeros");
}

func failEnsureIpAddressBadOctet() {
    ensureIpAddress("10.0.0.999");
}

func testEnsureIpAddressRejectsBadOctet() {
    testing.assertThrows("failEnsureIpAddressBadOctet", "routeros");
}

func testEnsureCidrAcceptsNetwork() {
    ensureCidr("192.168.88.0/24");
    ensureCidr("2001:db8::/64");
    testing.assertTrue(true);
}

func failEnsureCidrNoPrefix() {
    ensureCidr("192.168.88.0");
}

func testEnsureCidrRejectsMissingPrefix() {
    testing.assertThrows("failEnsureCidrNoPrefix", "routeros");
}

func failEnsureCidrBadPrefix() {
    ensureCidr("192.168.88.0/33");
}

func testEnsureCidrRejectsBadPrefix() {
    testing.assertThrows("failEnsureCidrBadPrefix", "routeros");
}

func testEnsureInNetworkAcceptsMember() {
    ensureInNetwork("192.168.77.0/24", "192.168.77.10", "gateway");
    testing.assertTrue(true);
}

func failEnsureInNetworkOutside() {
    ensureInNetwork("192.168.77.0/24", "192.168.78.1", "gateway");
}

func testEnsureInNetworkRejectsOutsider() {
    testing.assertThrows("failEnsureInNetworkOutside", "routeros");
}

func testEnsureMacAcceptsBothCases() {
    ensureMac("AA:BB:CC:DD:EE:FF");
    ensureMac("aa:bb:cc:0d:ee:0f");
    testing.assertTrue(true);
}

func failEnsureMacNoColons() {
    ensureMac("AABBCCDDEEFF");
}

func testEnsureMacRejectsMissingColons() {
    testing.assertThrows("failEnsureMacNoColons", "routeros");
}

func failEnsureMacTooShort() {
    ensureMac("AA:BB:CC:DD:EE");
}

func testEnsureMacRejectsFivePairs() {
    testing.assertThrows("failEnsureMacTooShort", "routeros");
}

func failEnsureMacBadHex() {
    ensureMac("AA:BB:CC:DD:EE:GG");
}

func testEnsureMacRejectsBadHex() {
    testing.assertThrows("failEnsureMacBadHex", "routeros");
}

func failEnsureMacUnevenPair() {
    ensureMac("AA:BB:CC:DD:EE:F");
}

func testEnsureMacRejectsUnevenPair() {
    testing.assertThrows("failEnsureMacUnevenPair", "routeros");
}

func testNormalizedAddressListSingle() {
    testing.assertEqual(normalizedAddressList("1.1.1.1"), "1.1.1.1");
}

func testNormalizedAddressListTrimsSpaces() {
    testing.assertEqual(normalizedAddressList(" 1.1.1.1 , 9.9.9.9 "), "1.1.1.1,9.9.9.9");
}

func failNormalizedAddressListEmptyEntry() {
    normalizedAddressList("1.1.1.1,,9.9.9.9");
}

func testNormalizedAddressListRejectsEmptyEntry() {
    testing.assertThrows("failNormalizedAddressListEmptyEntry", "routeros");
}

func failNormalizedAddressListBadEntry() {
    normalizedAddressList("1.1.1.1,example.com");
}

func testNormalizedAddressListRejectsHostname() {
    testing.assertThrows("failNormalizedAddressListBadEntry", "routeros");
}

func testIsIpAddress() {
    testing.assertTrue(isIpAddress("192.168.88.254"));
    testing.assertTrue(isIpAddress("2001:db8::1"));
    testing.assertTrue(isIpAddress("  10.0.0.1  "));
    testing.assertFalse(isIpAddress("ether1"));
    testing.assertFalse(isIpAddress("10.0.0.999"));
    testing.assertFalse(isIpAddress(""));
}

func testRowIntParsesAndDefaults() {
    def row as map of string to string init {"sent": "4", "junk": "many"};
    testing.assertEqual(rowInt($row, "sent"), 4);
    testing.assertEqual(rowInt($row, "missing"), 0);
    testing.assertEqual(rowInt($row, "junk"), 0);
}

func testEnsureHostAcceptsNamesAndAddresses() {
    ensureHost("1.1.1.1");
    ensureHost("router.lan");
    ensureHost("2001:db8::1");
    testing.assertTrue(true);
}

func failEnsureHostEmpty() {
    ensureHost("");
}

func testEnsureHostRejectsEmpty() {
    testing.assertThrows("failEnsureHostEmpty", "routeros");
}

func failEnsureHostSpaces() {
    ensureHost("my router");
}

func testEnsureHostRejectsSpaces() {
    testing.assertThrows("failEnsureHostSpaces", "routeros");
}

# a self-move is caught before the request reaches the router, so the
# zero-value client is never dialled
func failMoveRuleOntoItself() {
    def c as Client;
    moveRule($c, "/ip/firewall/filter", "*A", "*A");
}

func testMoveRuleRejectsSelfMove() {
    testing.assertThrows("failMoveRuleOntoItself", "routeros");
}

func failMoveRuleEmptyId() {
    def c as Client;
    moveRule($c, "/ip/firewall/filter", "   ", "*A");
}

func testMoveRuleRejectsEmptyId() {
    testing.assertThrows("failMoveRuleEmptyId", "routeros");
}

func failMoveRuleEmptyPath() {
    def c as Client;
    moveRule($c, "", "*A", "*B");
}

func testMoveRuleRejectsEmptyPath() {
    testing.assertThrows("failMoveRuleEmptyPath", "routeros");
}

func testSetVerboseReturnsACopy() {
    def c as Client;
    testing.assertFalse(isVerbose($c));
    def loud as Client init setVerbose($c, true);
    testing.assertTrue(isVerbose($loud));
    # value semantics: the original is untouched
    testing.assertFalse(isVerbose($c));
    testing.assertEqual($loud.user, $c.user);
}

func testSetVerboseCanTurnItOffAgain() {
    def c as Client;
    def loud as Client init setVerbose($c, true);
    def quiet as Client init setVerbose($loud, false);
    testing.assertTrue(isVerbose($loud));
    testing.assertFalse(isVerbose($quiet));
}

func testFormatAttrsRendersPairsInOrder() {
    def attrs as map of string to string init {"chain": "forward", "action": "drop"};
    testing.assertEqual(formatAttrs($attrs), " chain=forward action=drop");
}

func testFormatAttrsEmptyIsEmptyString() {
    def attrs as map of string to string init {};
    testing.assertEqual(formatAttrs($attrs), "");
}

func testFormatQueries() {
    def q as list of string init ["?name=ether1"];
    testing.assertEqual(formatQueries($q), " ?name=ether1");
    def none as list of string init [];
    testing.assertEqual(formatQueries($none), "");
}

# verbose mode prints what goes on the wire, and that includes credentials
func testSecretKeysAreRedacted() {
    testing.assertTrue(isSecretKey("password"));
    testing.assertTrue(isSecretKey("secret"));
    testing.assertTrue(isSecretKey("passphrase"));
    testing.assertTrue(isSecretKey("ipsec-secret"));
    testing.assertTrue(isSecretKey("private-key"));
    testing.assertTrue(isSecretKey("wpa2-pre-shared-key"));
    testing.assertTrue(isSecretKey("wpa-pre-shared-key"));
    testing.assertTrue(isSecretKey("security.passphrase"));
}

# the near-misses: none of these carry a credential
func testNonSecretKeysAreNotRedacted() {
    testing.assertFalse(isSecretKey("public-key"));
    testing.assertFalse(isSecretKey("key-usage"));
    testing.assertFalse(isSecretKey("passive"));
    testing.assertFalse(isSecretKey("passthrough"));
    testing.assertFalse(isSecretKey("user"));
    testing.assertFalse(isSecretKey("address"));
}

func testFormatAttrsRedactsTheValueNotTheKey() {
    def attrs as map of string to string init {"user": "router", "password": "hunter2"};
    testing.assertEqual(formatAttrs($attrs), " user=router password=<redacted>");
}

func testLoggedValuePassesThroughOrdinaryValues() {
    testing.assertEqual(loggedValue("address", "192.168.88.1/24"), "192.168.88.1/24");
    testing.assertEqual(loggedValue("password", "hunter2"), "<redacted>");
}

func testTruthyWordAcceptsAffirmatives() {
    testing.assertTrue(truthyWord("1"));
    testing.assertTrue(truthyWord("yes"));
    testing.assertTrue(truthyWord("true"));
    testing.assertTrue(truthyWord("on"));
    testing.assertTrue(truthyWord("  YES  "));
    testing.assertTrue(truthyWord("True"));
}

func testTruthyWordRejectsEverythingElse() {
    testing.assertFalse(truthyWord(""));
    testing.assertFalse(truthyWord("0"));
    testing.assertFalse(truthyWord("no"));
    testing.assertFalse(truthyWord("false"));
    testing.assertFalse(truthyWord("maybe"));
}
