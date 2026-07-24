# Certificates

File: `src/topics/certificates.j`. Path: `/certificate`
(`CERTIFICATE_PATH`).

## Background

Everything TLS on the router hangs off the certificate store: the
secure API (`api-ssl`), WebFig over HTTPS (`www-ssl`), SSTP/OVPN
servers. The services topic flags an ssl service without a certificate
as `invalid` - this topic is where that gets fixed. Three ways to get a
certificate, in order of preference:

1. **Let's Encrypt via RouterOS** (`enableLetsEncrypt`) - when the
   router's port 80 is reachable from the internet under its DNS name
   (pair with [cloud.md](cloud.md) for the name). The router solves the
   challenge and renews itself. v7.
2. **Externally obtained** (`importCertificatePem`) - your CA, or the
   Jennifer `acme` module when the router is behind NAT (dns-01 flow
   run on the Jennifer host; see below).
3. **Self-signed** (`generateSelfSigned`) - LAN-only services where
   clients can trust manually.

A correct clock is a hard prerequisite for all of it -
[clock.md](clock.md) first.

## Struct

```jennifer
mt.Certificate {
    id, name, commonName, issuer,
    expiresAfter, invalidAfter,    # "51w6d" / absolute date
    hasPrivateKey,                 # usable for serving?
    trusted, isCa
}
```

## Functions

| Function | Purpose |
|---|---|
| `certificates(c)` / `certificateByName(c, name)` | the store |
| `expiringCertificates(c, withinDays)` | the renewal audit |
| `generateSelfSigned(c, name, commonName, days)` → id | on-router self-signed |
| `enableLetsEncrypt(c, dnsName)` | RouterOS built-in ACME (http-01) |
| `importCertificatePem(c, name, certPem, keyPem)` | drop in an external cert |
| `assignServiceCertificate(c, "api-ssl", certName)` | wire it to a service |
| `removeCertificate(c, name)` | delete from the store |

## Examples

Secure the API for the LAN with a self-signed certificate:

```jennifer
mt.generateSelfSigned($c, "router-lan", "router.lan", 1095);
mt.assignServiceCertificate($c, "api-ssl", "router-lan");
mt.restrictService($c, "api-ssl", "10.0.9.0/24");
# from now on, connect with mt.connectTLS(...)
```

A real certificate on an internet-reachable router:

```jennifer
mt.enableCloudDns($c);
def name as string init mt.routerDnsName($c);
mt.enableLetsEncrypt($c, $name);      # blocks while the challenge runs
mt.assignServiceCertificate($c, "www-ssl", $name);
```

The renewal audit (run weekly from a host-side cron / `/loop`):

```jennifer
def soon as list of mt.Certificate init mt.expiringCertificates($c, 30);
for (def cert in $soon) {
    io.printf("renew soon: %s (%s) expires in %s\n",
        $cert.name, $cert.commonName, $cert.expiresAfter);
}
```

## The Jennifer `acme` flow (router behind NAT)

The Jennifer *host* obtains the certificate (dns-01 with your public
DNS provider, or http-01 served by the host), then pushes it in - this
is what `importCertificatePem` exists for:

```jennifer
use crypto;
import "acme.j";
# 1. key + CSR on the host
def key as bytes init crypto.ecGenerateKey("p256");
def csr as bytes init crypto.csr($key, "vpn.example.org", []);
# 2. the acme dance (order, challenge, finalize - see the acme module docs;
#    use the staging CA first!)
# ... def certPem as string init acme.downloadCertificate($client, $order);
# 3. push key + cert to the router and wire it up
# mt.importCertificatePem($c, "vpn-example-org", $certPem,
#     convert.stringFromBytes($key, "utf-8"));
# mt.assignServiceCertificate($c, "api-ssl", "vpn-example-org");
```

Renewal is host-driven: re-run the flow when
`expiringCertificates(c, 30)` names the certificate. Import uses
temporary files on the router (`/file` + `/certificate/import`) and
removes them afterwards so the key never lingers on flash - still,
treat the transport with respect: use `connectTLS`.

## Pitfalls

- **Wrong clock = broken TLS.** A router that booted without NTP thinks
  it is 1970 and rejects every certificate. [clock.md](clock.md).
- `enableLetsEncrypt` needs port 80 reachable *from the internet* under
  the DNS name - a NATed or firewalled router fails the challenge (use
  the `acme` flow instead).
- `generateSelfSigned` blocks a few seconds (the router computes the
  key). Clients must trust the result explicitly - fine for admin
  tools, wrong for public services.
- Import order and naming: the `.crt` may contain the full chain;
  key and certificate import under the same store `name` merge into
  one usable entry (`hasPrivateKey == true`).

## Related

- [services.md](services.md) (the `invalid` flag this topic fixes),
  [clock.md](clock.md), [cloud.md](cloud.md) (the DNS name),
  [files.md](files.md) (the temp-file transport underneath).
