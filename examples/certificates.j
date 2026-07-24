#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * certificates example - TLS certificates for the router's services.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/certificates.j
 */

use io;
use os;

import "../src/routeros.j" as mt;

def host as string init os.getEnv("MT_HOST");
def user as string init os.getEnv("MT_USER");
def password as string init os.getEnv("MT_PASSWORD");

if ($host == "" or $user == "") {
    io.printf("set MT_HOST, MT_USER and MT_PASSWORD first\n");
    exit 1;
}

def c as mt.Client init mt.connect($host, $user, $password);

def certs as list of mt.Certificate init mt.certificates($c);
for (def cert in $certs) {
    io.printf("cert %s (%s) expires %s key=%t\n",
        $cert.name, $cert.commonName, $cert.expiresAfter, $cert.hasPrivateKey);
}
def soon as list of mt.Certificate init mt.expiringCertificates($c, 30);
io.printf("%d certificates expire within 30 days\n", len($soon));

#   mt.generateSelfSigned($c, "router-lan", "router.lan", 1095);
#   mt.assignServiceCertificate($c, "api-ssl", "router-lan");
#   mt.enableLetsEncrypt($c, "router.example.org");

mt.disconnect($c);
