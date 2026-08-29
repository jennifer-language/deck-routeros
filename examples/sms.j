#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * sms example - text messages over the cellular modem.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Needs a router with an LTE modem and a SIM.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/sms.j
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

def s as mt.SmsSettings init mt.smsSettings($c);
io.printf("sms receive=%t port=%s keepMax=%d\n", $s.receiveEnabled, $s.port, $s.keepMaxSms);
if ($s.allowedNumber == "") {
    io.printf("  allowed-number is unset - any sender is honoured\n");
} else {
    io.printf("  only %s is honoured\n", $s.allowedNumber);
}

def inbox as list of mt.SmsMessage init mt.smsInbox($c);
io.printf("inbox (%d):\n", len($inbox));
for (def m in $inbox) {
    io.printf("  %s  %s: %s\n", $m.timestamp, $m.phone, $m.message);
}

# The modem ports available to receive/send on:
for (def l in mt.lteInterfaces($c)) {
    io.printf("modem port: %s\n", $l.name);
}

# Start receiving, and restrict which sender the router will act on
# (RouterOS can run commands sent by SMS):
#   mt.enableSmsReceive($c, "lte1");
#   mt.restrictSms($c, "+441632960123", 50);

# Alert over the modem - this is the path that survives a dead uplink:
#   mt.sendSms($c, "lte1", "+441632960123", "gw1: uplink down");

# Housekeeping (the inbox does not prune itself):
#   io.printf("cleared %d\n", mt.clearSmsInbox($c));

mt.disconnect($c);
