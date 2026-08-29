# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - white-box tests for the certificates topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testDurationToDaysForms() {
    testing.assertEqual(durationToDays("52w"), 364);
    testing.assertEqual(durationToDays("4w2d"), 30);
    testing.assertEqual(durationToDays("1d12h"), 1);
    testing.assertEqual(durationToDays("23h59m"), 0);
    testing.assertEqual(durationToDays("90"), 0);
    testing.assertEqual(durationToDays("2d"), 2);
}

func testDurationToDaysUnparseable() {
    testing.assertEqual(durationToDays(""), -1);
    testing.assertEqual(durationToDays("soon"), -1);
    testing.assertEqual(durationToDays("10q"), -1);
    testing.assertEqual(durationToDays("w"), -1);
}

func testCertificateFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "router-lan",
        "common-name": "router.lan",
        "issuer": "CN=router.lan",
        "expires-after": "51w6d",
        "invalid-after": "2027-07-20 12:00:00",
        "private-key": "true",
        "trusted": "true",
        "ca": "false"
    };
    def cert as Certificate init certificateFromRow($row);
    testing.assertEqual($cert.id, "*1");
    testing.assertEqual($cert.name, "router-lan");
    testing.assertEqual($cert.commonName, "router.lan");
    testing.assertEqual($cert.issuer, "CN=router.lan");
    testing.assertEqual($cert.expiresAfter, "51w6d");
    testing.assertTrue($cert.hasPrivateKey);
    testing.assertTrue($cert.trusted);
    testing.assertFalse($cert.isCa);
}

func testCertificateFromSparseRow() {
    def row as map of string to string init {".id": "*2", "name": "template"};
    def cert as Certificate init certificateFromRow($row);
    testing.assertEqual($cert.expiresAfter, "");
    testing.assertFalse($cert.hasPrivateKey);
    testing.assertFalse($cert.isCa);
}

func testExpiringFromFilters() {
    def certs as list of Certificate init [
        Certificate{
            id: "*1",
            name: "old",
            commonName: "a",
            issuer: "x",
            expiresAfter: "2w",
            invalidAfter: "",
            hasPrivateKey: true,
            trusted: false,
            isCa: false
        },
        Certificate{
            id: "*2",
            name: "fresh",
            commonName: "b",
            issuer: "x",
            expiresAfter: "51w6d",
            invalidAfter: "",
            hasPrivateKey: true,
            trusted: false,
            isCa: false
        },
        Certificate{
            id: "*3",
            name: "unknown",
            commonName: "c",
            issuer: "x",
            expiresAfter: "",
            invalidAfter: "",
            hasPrivateKey: false,
            trusted: false,
            isCa: false
        }
    ];
    def soon as list of Certificate init expiringFrom($certs, 30);
    testing.assertEqual(len($soon), 1);
    testing.assertEqual($soon[0].name, "old");
}

func failPemCertificateJunk() {
    ensurePemCertificate("not a pem");
}

func testEnsurePemCertificateRejectsJunk() {
    testing.assertThrows("failPemCertificateJunk", "routeros");
}

func testEnsurePemCertificateAcceptsPem() {
    ensurePemCertificate("-----BEGIN CERTIFICATE-----\nMIIB...\n-----END CERTIFICATE-----\n");
    testing.assertTrue(true);
}

func failPemKeyJunk() {
    ensurePemKey("-----BEGIN CERTIFICATE-----");
}

func testEnsurePemKeyRejectsCertificate() {
    testing.assertThrows("failPemKeyJunk", "routeros");
}

func testEnsurePemKeyAcceptsForms() {
    ensurePemKey("-----BEGIN PRIVATE KEY-----\nMIG...\n-----END PRIVATE KEY-----\n");
    ensurePemKey("-----BEGIN EC PRIVATE KEY-----\nMHc...\n-----END EC PRIVATE KEY-----\n");
    testing.assertTrue(true);
}
