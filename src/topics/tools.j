# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - diagnostics: ping, traceroute, bandwidth test, fetch, e-mail.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API command that sends ICMP echo requests. */
export def const PING_COMMAND as string init "/ping";

/** RouterOS API command that traces the path to a host. */
export def const TRACEROUTE_COMMAND as string init "/tool/traceroute";

/** RouterOS API command that downloads a URL from the router. */
export def const FETCH_COMMAND as string init "/tool/fetch";

/** RouterOS API path of the e-mail (SMTP) settings. */
export def const EMAIL_PATH as string init "/tool/e-mail";

/** RouterOS API command that runs a throughput test against a btest server. */
export def const BANDWIDTH_TEST_COMMAND as string init "/tool/bandwidth-test";

def const BTEST_DIRECTIONS as list of string init ["receive", "transmit", "both"];

/**
 * The outcome of a ping from the router.
 *
 * @field {string} host       the host that answered (usually the target)
 * @field {int}    sent       probes sent
 * @field {int}    received   replies received
 * @field {int}    packetLoss loss in percent (0 = all replies arrived)
 * @field {string} minRtt     fastest round trip as reported (e.g. "1ms52us")
 * @field {string} avgRtt     average round trip as reported
 * @field {string} maxRtt     slowest round trip as reported
 * @field {bool}   reachable  true when at least one reply arrived
 */
export def struct PingResult {
    host as string,
    sent as int,
    received as int,
    packetLoss as int,
    minRtt as string,
    avgRtt as string,
    maxRtt as string,
    reachable as bool
};

/**
 * The outcome of a bandwidth test from the router.
 *
 * Rates are bits per second as the router reports them (strings).
 *
 * @field {string} status      the tester's final status ("done testing" on success)
 * @field {string} direction   tested direction ("receive", "transmit", "both")
 * @field {string} txCurrent   transmit rate at the end of the test
 * @field {string} txAverage   average transmit rate over the whole test
 * @field {string} rxCurrent   receive rate at the end of the test
 * @field {string} rxAverage   average receive rate over the whole test
 * @field {int}    lostPackets packets lost during the test
 */
export def struct BandwidthResult {
    status as string,
    direction as string,
    txCurrent as string,
    txAverage as string,
    rxCurrent as string,
    rxAverage as string,
    lostPackets as int
};

/**
 * Ping a host from the router (4 probes).
 *
 * Tells you whether the ROUTER can reach the host - useful for checking
 * an uplink, a gateway, or a device on the LAN from the router's point
 * of view.
 *
 * @param {Client} c    an open client
 * @param {string} host IP address or DNS name to ping
 * @return {PingResult} the summary; check `reachable` first
 * @throws {Error} kind "routeros" on an empty host, kind "mikrotik"
 *                 when the router cannot even try (e.g. bad DNS name)
 * @example
 *   def p as mt.PingResult init mt.ping($c, "1.1.1.1");
 *   if (not $p.reachable) { io.printf("uplink down!\n"); }
 */
export func ping(c as Client, host as string) {
    return pingWith($c, $host, 4);
}

/**
 * Ping a host from the router with a chosen probe count.
 *
 * The count is mandatory under the hood: an unbounded RouterOS ping
 * never returns, so routeros always sends one.
 *
 * @param {Client} c     an open client
 * @param {string} host  IP address or DNS name to ping
 * @param {int}    count probes to send, 1-100
 * @return {PingResult} the summary
 * @throws {Error} kind "routeros" on an empty host or a count outside 1-100
 */
export func pingWith(c as Client, host as string, count as int) {
    def target as string init strings.trim($host);
    ensureHost($target);
    if ($count < 1 or $count > 100) {
        raiseError("the ping count must be between 1 and 100");
    }
    def rows as list of map of string to string init mikrotik.talk($c.session, PING_COMMAND,
        {"address": $target, "count": convert.toString($count)});
    return pingResultFromRow(mergeRows($rows));
}

/**
 * Test whether the router can reach a host (a yes/no ping).
 *
 * @param {Client} c    an open client
 * @param {string} host IP address or DNS name
 * @return {bool} true when at least one of 4 probes came back
 * @throws {Error} kind "routeros" on an empty host
 */
export func isReachable(c as Client, host as string) {
    def result as PingResult init ping($c, $host);
    return $result.reachable;
}

/**
 * Measure throughput between the router and a btest server.
 *
 * The target must run the bandwidth-test server: another MikroTik
 * (enabled under "/tool/bandwidth-server") or MikroTik's btest tool.
 * Caution: the test deliberately SATURATES the link and loads both
 * CPUs while it runs - do not fire it at a production uplink during
 * business hours. If the server requires credentials, use
 * `bandwidthTestWith`.
 *
 * @param {Client} c         an open client
 * @param {string} host      the btest server to test against
 * @param {int}    seconds   test duration, 1-300 (10 is a good start)
 * @param {string} direction "receive" (download to the router),
 *                           "transmit" (upload from it), or "both"
 * @return {BandwidthResult} the measured rates
 * @throws {Error} kind "routeros" on bad input, kind "mikrotik" when
 *                 the server is unreachable or refuses
 */
export func bandwidthTest(c as Client, host as string, seconds as int, direction as string) {
    return bandwidthRun($c, $host, $seconds, $direction, "", "");
}

/**
 * Like `bandwidthTest`, authenticating against the btest server.
 *
 * @param {Client} c         an open client
 * @param {string} host      the btest server to test against
 * @param {int}    seconds   test duration, 1-300
 * @param {string} direction "receive", "transmit", or "both"
 * @param {string} user      user name on the btest server
 * @param {string} password  password on the btest server
 * @return {BandwidthResult} the measured rates
 * @throws {Error} kind "routeros" on bad input, kind "mikrotik" when
 *                 the server is unreachable or refuses the credentials
 */
export func bandwidthTestWith(c as Client, host as string, seconds as int, direction as string, user as string, password as string) {
    return bandwidthRun($c, $host, $seconds, $direction, $user, $password);
}

/**
 * Fold the merged ping rows into a PingResult.
 *
 * `reachable` is computed here: at least one reply arrived.
 *
 * @param {map of string to string} row the merged ping progress rows
 * @return {PingResult} the typed summary
 * @internal
 */
func pingResultFromRow(row as map of string to string) {
    def received as int init rowInt($row, "received");
    return PingResult{
        host: rowValue($row, "host"),
        sent: rowInt($row, "sent"),
        received: $received,
        packetLoss: rowInt($row, "packet-loss"),
        minRtt: rowValue($row, "min-rtt"),
        avgRtt: rowValue($row, "avg-rtt"),
        maxRtt: rowValue($row, "max-rtt"),
        reachable: $received > 0
    };
}

/**
 * Validate inputs and run the bandwidth test.
 *
 * @param {Client} c         an open client
 * @param {string} host      the btest server
 * @param {int}    seconds   duration, 1-300
 * @param {string} direction "receive", "transmit", or "both"
 * @param {string} user      btest credentials, "" to omit
 * @param {string} password  btest credentials, "" to omit
 * @return {BandwidthResult} the folded result
 * @throws {Error} kind "routeros" on bad input
 * @internal
 */
func bandwidthRun(c as Client, host as string, seconds as int, direction as string, user as string, password as string) {
    def target as string init strings.trim($host);
    ensureHost($target);
    ensureBandwidthParams($seconds, $direction);
    def attrs as map of string to string init {
        "address": $target,
        "duration": convert.toString($seconds),
        "direction": $direction
    };
    if ($user != "") {
        $attrs["user"] = $user;
    }
    if ($password != "") {
        $attrs["password"] = $password;
    }
    def rows as list of map of string to string init
        mikrotik.talk($c.session, BANDWIDTH_TEST_COMMAND, $attrs);
    return bandwidthResultFromRow(mergeRows($rows));
}

/**
 * Validate bandwidth-test duration and direction.
 *
 * @param {int}    seconds   duration, must be 1-300
 * @param {string} direction must be "receive", "transmit", or "both"
 * @throws {Error} kind "routeros" on either being out of range
 * @internal
 */
func ensureBandwidthParams(seconds as int, direction as string) {
    if ($seconds < 1 or $seconds > 300) {
        raiseError("the test duration must be between 1 and 300 seconds");
    }
    if (not lists.contains(BTEST_DIRECTIONS, $direction)) {
        raiseError("unknown direction \"" + $direction + "\" - use one of: " + strings.join(BTEST_DIRECTIONS, ", "));
    }
}

/**
 * Fold the merged bandwidth-test rows into a BandwidthResult.
 *
 * @param {map of string to string} row the merged progress rows
 * @return {BandwidthResult} the typed result
 * @internal
 */
func bandwidthResultFromRow(row as map of string to string) {
    return BandwidthResult{
        status: rowValue($row, "status"),
        direction: rowValue($row, "direction"),
        txCurrent: rowValue($row, "tx-current"),
        txAverage: rowValue($row, "tx-total-average"),
        rxCurrent: rowValue($row, "rx-current"),
        rxAverage: rowValue($row, "rx-total-average"),
        lostPackets: rowInt($row, "lost-packets")
    };
}

/**
 * One hop on a traceroute path.
 *
 * @field {string} address the hop's address, "" when it did not answer
 * @field {string} loss    packet loss at this hop as reported
 * @field {string} avgRtt  average round trip to this hop, "" when no reply
 * @field {string} status  the hop status as reported
 */
export def struct TracerouteHop {
    address as string,
    loss as string,
    avgRtt as string,
    status as string
};

/**
 * The outcome of a router-side fetch (download / webhook call).
 *
 * @field {string} status       "finished" on success, or the failure text
 * @field {bool}   ok           computed: the status equals "finished"
 * @field {string} downloaded   bytes downloaded as reported
 * @field {string} data         the response body (only when fetched to memory)
 */
export def struct FetchResult {
    status as string,
    ok as bool,
    downloaded as string,
    data as string
};

/**
 * Trace the network path from the router to a host.
 *
 * Shows every router (hop) between this router and the target, and where
 * the path breaks - the companion to `ping` when "it is slow" or "it
 * cannot be reached". Runs one probe per hop and returns.
 *
 * @param {Client} c    an open client
 * @param {string} host the IP address or DNS name to trace
 * @return {list of TracerouteHop} the hops in order
 * @throws {Error} kind "routeros" on an empty host
 * @example
 *   def hops as list of mt.TracerouteHop init mt.traceroute($c, "1.1.1.1");
 *   for (def h in $hops) { io.printf("%s %s (loss %s)\n", $h.address, $h.avgRtt, $h.loss); }
 */
export func traceroute(c as Client, host as string) {
    def target as string init strings.trim($host);
    ensureHost($target);
    def rows as list of map of string to string init mikrotik.talk($c.session,
        TRACEROUTE_COMMAND, {"address": $target, "count": "1"});
    def out as list of TracerouteHop init [];
    for (def row in $rows) {
        $out[] = tracerouteHopFromRow($row);
    }
    return $out;
}

/**
 * Fetch a URL from the router and return the response body.
 *
 * The router (not your host) makes the request - call a webhook, hit a
 * REST API, or check an external "what is my IP" service from the
 * router's own vantage point. The body is returned in `data`. For a
 * large download to storage, use `downloadFile`.
 *
 * @param {Client} c   an open client
 * @param {string} url the URL to fetch (http/https)
 * @return {FetchResult} status + the response body in `data`
 * @throws {Error} kind "routeros" on an empty/non-http URL,
 *                 kind "mikrotik" when the fetch fails
 * @example
 *   def r as mt.FetchResult init mt.fetchUrl($c, "https://ifconfig.co/ip");
 *   if ($r.ok) { io.printf("public IP: %s\n", $r.data); }
 */
export func fetchUrl(c as Client, url as string) {
    def target as string init strings.trim($url);
    if ($target == "" or not strings.startsWith($target, "http")) {
        raiseError("the fetch URL must be an http(s) URL");
    }
    def rows as list of map of string to string init mikrotik.talk($c.session,
        FETCH_COMMAND, {"url": $target, "output": "user", "mode": "https"});
    return fetchResultFromRow(mergeRows($rows));
}

/**
 * Download a URL to a file on the router's storage.
 *
 * @param {Client} c        an open client
 * @param {string} url      the URL to download
 * @param {string} fileName the destination file name on the router
 * @return {FetchResult} status + bytes downloaded
 * @throws {Error} kind "routeros" on bad input, kind "mikrotik" on failure
 */
export func downloadFile(c as Client, url as string, fileName as string) {
    def target as string init strings.trim($url);
    if ($target == "" or not strings.startsWith($target, "http")) {
        raiseError("the download URL must be an http(s) URL");
    }
    ensureName($fileName, "file");
    def rows as list of map of string to string init mikrotik.talk($c.session,
        FETCH_COMMAND, {"url": $target, "dst-path": $fileName, "mode": "https"});
    return fetchResultFromRow(mergeRows($rows));
}

/**
 * Configure the router's outgoing e-mail (SMTP) settings.
 *
 * Do this once; then `sendEmail` (and RouterOS scripts) can send alerts.
 * The password is write-only.
 *
 * @param {Client} c        an open client
 * @param {string} server   the SMTP server address
 * @param {int}    port     the SMTP port (e.g. 587)
 * @param {string} from     the From: address
 * @param {string} user     the SMTP login (may be "" for open relays)
 * @param {string} password the SMTP password ("" when no auth)
 * @throws {Error} kind "routeros" on a bad server or port
 */
export func configureEmail(c as Client, server as string, port as int, from as string, user as string, password as string) {
    ensureIpAddress($server);
    ensurePort($port);
    def attrs as map of string to string init
        {"address": strings.trim($server), "port": convert.toString($port), "from": $from};
    if ($user != "") {
        $attrs["user"] = $user;
    }
    if ($password != "") {
        $attrs["password"] = $password;
    }
    mikrotik.run($c.session, EMAIL_PATH + "/set", $attrs);
}

/**
 * Send an e-mail from the router (alerts, reports).
 *
 * Requires `configureEmail` first. The pairing with the scheduler or
 * netwatch turns the router into its own alerting system - a nightly
 * report, a "WAN went down" mail.
 *
 * @param {Client} c         an open client
 * @param {string} recipient the recipient address
 * @param {string} subject   the subject line
 * @param {string} body      the message body
 * @throws {Error} kind "routeros" on an empty recipient, kind "mikrotik"
 *                 when the SMTP send fails
 * @example
 *   mt.configureEmail($c, "10.0.9.25", 587, "router@example.org", "router", "secret");
 *   mt.sendEmail($c, "noc@example.org", "router booted", "the office router just started");
 */
export func sendEmail(c as Client, recipient as string, subject as string, body as string) {
    def target as string init strings.trim($recipient);
    if ($target == "") {
        raiseError("the recipient must not be empty");
    }
    mikrotik.run($c.session, EMAIL_PATH + "/send",
        {"to": $target, "subject": $subject, "body": $body});
}

/**
 * Fold a reply row into a TracerouteHop.
 *
 * @param {map of string to string} row a traceroute reply row
 * @return {TracerouteHop} the typed hop
 * @internal
 */
func tracerouteHopFromRow(row as map of string to string) {
    return TracerouteHop{
        address: rowValue($row, "address"),
        loss: rowValue($row, "loss"),
        avgRtt: rowValue($row, "avg"),
        status: rowValue($row, "status")
    };
}

/**
 * Fold the merged fetch rows into a FetchResult.
 *
 * `ok` is computed here: the status equals "finished".
 *
 * @param {map of string to string} row the merged fetch progress rows
 * @return {FetchResult} the typed result
 * @internal
 */
func fetchResultFromRow(row as map of string to string) {
    def status as string init rowValue($row, "status");
    return FetchResult{
        status: $status,
        ok: $status == "finished",
        downloaded: rowValue($row, "downloaded"),
        data: rowValue($row, "data")
    };
}
