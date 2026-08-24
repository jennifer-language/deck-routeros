# Tools: diagnostics from the router

File: `src/topics/tools.j`. Commands: `/ping` (`PING_COMMAND`),
`/tool/bandwidth-test` (`BANDWIDTH_TEST_COMMAND`).

## Background

These run **on the router**, so they answer a different question than
the same tools on your workstation: "can the *router* reach X?" That is
what you want when debugging an uplink, a VPN, or a device the router
should serve.

Both are *streaming* commands in RouterOS - they emit progress rows and
would run forever unbounded. routeros always sends a bound (a probe
count, a duration), folds the progress rows, and returns one typed
result; the calls are guaranteed to return.

## Structs

```jennifer
mt.PingResult {
    host, sent, received, packetLoss,    # counts/loss as ints
    minRtt, avgRtt, maxRtt,              # e.g. "1ms52us", as reported
    reachable                            # computed: received > 0
}
mt.BandwidthResult {
    status,                              # "done testing" on success
    direction, txCurrent, txAverage, rxCurrent, rxAverage,
    lostPackets
}
```

## Functions

| Function | Purpose |
|---|---|
| `ping(c, host)` → `PingResult` | 4 probes; host is IP or DNS name |
| `pingWith(c, host, count)` → `PingResult` | 1-100 probes |
| `isReachable(c, host)` → bool | the yes/no shortcut |
| `bandwidthTest(c, host, seconds, direction)` → `BandwidthResult` | throughput against a btest server |
| `bandwidthTestWith(c, host, seconds, direction, user, password)` | same, with btest credentials |

Direction is `"receive"` (download to the router), `"transmit"`, or
`"both"`; duration 1-300 seconds.

## Examples

Uplink health check:

```jennifer
def p as mt.PingResult init mt.ping($c, "1.1.1.1");
if ($p.reachable) {
    io.printf("uplink ok: %d/%d, avg %s\n", $p.received, $p.sent, $p.avgRtt);
} else {
    io.printf("uplink down (loss %d percent)\n", $p.packetLoss);
}
```

Is DNS resolution itself the problem? Compare IP vs. name:

```jennifer
if (mt.isReachable($c, "1.1.1.1") and not mt.isReachable($c, "example.org")) {
    io.printf("routing works, DNS does not - check dns settings\n");
}
```

Measure a link between two MikroTiks (the far end needs
`/tool/bandwidth-server` enabled):

```jennifer
def bw as mt.BandwidthResult init mt.bandwidthTest($c, "192.168.88.2", 10, "both");
io.printf("rx %s bps / tx %s bps, lost %d\n",
    $bw.rxAverage, $bw.txAverage, $bw.lostPackets);
```

## Traceroute, fetch, and e-mail

Beyond ping and bandwidth-test, the tools topic covers three more
router-side diagnostics:

**Traceroute** — the path to a host, hop by hop, and where it breaks:

```jennifer
def hops as list of mt.TracerouteHop init mt.traceroute($c, "1.1.1.1");
for (def h in $hops) {
    io.printf("%s %s (loss %s) %s\n", $h.address, $h.avgRtt, $h.loss, $h.status);
}
```

**Fetch** — the router makes an HTTP(S) request from *its* vantage
point: call a webhook, hit a REST API, or check its own public IP.

```jennifer
def ip as mt.FetchResult init mt.fetchUrl($c, "https://ifconfig.co/ip");
if ($ip.ok) { io.printf("public IP: %s\n", $ip.data); }
mt.downloadFile($c, "https://example.org/config.rsc", "config.rsc");   # to storage
```

**E-mail** — configure SMTP once, then the router (or its scripts) can
alert. Almost every real relay wants TLS, so reach for
`configureEmailWith` and its `EMAIL_TLS_*` mode; the server may be a DNS
name or an IP:

```jennifer
mt.configureEmailWith($c, "smtp.example.org", 587,
    "[MikroTik gw1] <router@example.org>", "router", "secret",
    mt.EMAIL_TLS_STARTTLS);
mt.sendEmail($c, "noc@example.org", "WAN down", "the primary uplink just failed");
```

`configureEmail(c, server, port, from, user, password)` is the same call
without the TLS argument, leaving the router's current mode alone.
`emailSettings(c)` reads the configuration back as an `EmailSettings`
(the password is write-only and never returned):

```jennifer
def e as mt.EmailSettings init mt.emailSettings($c);
if ($e.tls == mt.EMAIL_TLS_NONE) { io.printf("alerts leave in the clear\n"); }
```

RouterOS 7.12 renamed these properties (`address` → `server`,
`start-tls` → `tls`). Both calls read the router's own settings row
first and write whichever spelling it uses, so one call works across
versions — on a pre-7.12 router `EMAIL_TLS_STARTTLS` becomes
`start-tls=yes` and `EMAIL_TLS_IMPLICIT` becomes `start-tls=tls-only`.

Pair `sendEmail` with [scheduler.md](scheduler.md) (a nightly report) or
[netwatch.md](netwatch.md) (a down-script that mails an alert) to turn
the router into its own monitoring system.

## Pitfalls

- **The bandwidth test saturates the link on purpose** and loads both
  CPUs. Do not aim it at a production uplink during business hours,
  and take results from small routers with a grain of salt - the CPU,
  not the link, may be the bottleneck.
- The target of a bandwidth test must run a btest server (another
  MikroTik, or MikroTik's btest utility); a plain host refuses.
- A ping to a DNS name requires working resolver settings on the
  router ([dns.md](dns.md)); otherwise the command fails with a
  router error (`kind: "mikrotik"`).
- `packetLoss` of 100 with `sent > 0` and a reachable gateway usually
  means a firewall drops ICMP, not that the host is down.
- RTT strings like `"1ms52us"` are RouterOS-formatted; routeros keeps
  them verbatim rather than guessing at parsing rules.

## Related

- [dns.md](dns.md), [routing.md](routing.md),
  [wireguard.md](wireguard.md) (ping the tunnel address to verify a
  VPN end-to-end).
