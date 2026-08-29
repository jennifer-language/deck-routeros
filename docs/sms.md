<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# SMS

File: `src/topics/sms.j`. Paths: `/tool/sms` (`SMS_PATH`),
`/tool/sms/inbox` (`SMS_INBOX_PATH`), `/tool/sms/send`
(`SMS_SEND_COMMAND`).

## Background

A router with a cellular modem ([lte.md](lte.md)) can send and receive
text messages. That matters for one reason: **SMS leaves when the uplink
is what broke**. An e-mail alert about a dead WAN never arrives; a text
over the modem does. Pair it with [netwatch.md](netwatch.md) or the
[scheduler.md](scheduler.md) and the router tells you itself.

Reception is **off by default** - a router with a SIM keeps nothing that
arrives until you turn it on, and you must name the modem port it
receives on.

RouterOS can also *execute commands* sent by SMS. That is why
`restrictSms` exists: `allowedNumber` is the sender the router will act
on, and setting it is the difference between "anyone who learns the SIM
number can drive this router" and "only this number can".

## Structs

```jennifer
mt.SmsSettings { receiveEnabled, port, channel, allowedNumber,
                 keepMaxSms, autoErase }
mt.SmsMessage  { id, phone, message, timestamp, kind }
```

## Functions

| Function | Purpose |
|---|---|
| `smsSettings(c)` → `SmsSettings` | the current settings |
| `enableSmsReceive(c, port)` | start storing incoming messages |
| `disableSmsReceive(c)` | stop storing them (the inbox is kept) |
| `restrictSms(c, allowedNumber, keepMaxSms)` | the sender to honour, how many to keep |
| `sendSms(c, port, phoneNumber, message)` | send a message |
| `smsInbox(c)` → `list of SmsMessage` | the received messages |
| `removeSmsMessage(c, id)` | delete one |
| `clearSmsInbox(c)` → `int` | empty the inbox, returns how many went |

## Example

Alerting from a site whose uplink is the problem:

```jennifer
mt.sendSms($c, "lte1", "+441632960123", "gw1: uplink down");
```

Receive, restrict, and read:

```jennifer
mt.enableSmsReceive($c, "lte1");
mt.restrictSms($c, "+441632960123", 50);

for (def m in mt.smsInbox($c)) {
    io.printf("%s  %s: %s\n", $m.timestamp, $m.phone, $m.message);
}
io.printf("cleared %d\n", mt.clearSmsInbox($c));
```

## Pitfalls

- **Reception is off until you enable it**, and enabling needs the modem
  port - `lteInterfaces(c)` from [lte.md](lte.md) lists them (usually
  `lte1`).
- **Set `allowedNumber`** if the SIM number is at all guessable.
  Unrestricted, remote SMS commands are an unauthenticated path onto the
  router.
- **The inbox fills up.** `keepMaxSms` caps it; nothing prunes on its
  own unless the router's `autoErase` is on, so a long-running box wants
  `clearSmsInbox` on a schedule.
- Phone numbers are validated leniently - digits plus `+ - ( )` and
  spaces - because national formats vary. It catches a name passed where
  a number belongs, not a wrong number.
- A modem that is registered but refusing to send is usually out of
  credit or barred for premium/roaming SMS; the failure comes back as
  `Error{kind: "mikrotik"}` from the modem, not from routeros.

## Related

- [lte.md](lte.md) (the modem and its ports),
  [netwatch.md](netwatch.md) (what to trigger sending),
  [scheduler.md](scheduler.md), [tools.md](tools.md) (e-mail alerting,
  for when the uplink is up).
