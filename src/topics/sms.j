# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - SMS over the cellular modem: settings, sending, the inbox.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the SMS settings. */
export def const SMS_PATH as string init "/tool/sms";

/** RouterOS API path of the received-message store. */
export def const SMS_INBOX_PATH as string init "/tool/sms/inbox";

/** RouterOS API command that sends a text message. */
export def const SMS_SEND_COMMAND as string init "/tool/sms/send";

def const PHONE_CHARS as string init "0123456789+-() ";

/**
 * The router's SMS settings.
 *
 * @field {bool}   receiveEnabled true when the router stores incoming messages
 * @field {string} port           the modem port messages go through (e.g. "lte1")
 * @field {string} channel        the modem channel, "" for the default
 * @field {string} allowedNumber  the only sender accepted for remote
 *                                commands, "" when unrestricted
 * @field {int}    keepMaxSms     how many received messages are kept
 * @field {bool}   autoErase      true when the oldest message is dropped at the cap
 */
export def struct SmsSettings {
    receiveEnabled as bool,
    port as string,
    channel as string,
    allowedNumber as string,
    keepMaxSms as int,
    autoErase as bool
};

/**
 * One received text message.
 *
 * @field {string} id        internal RouterOS id
 * @field {string} phone     the sender's number
 * @field {string} message   the message text
 * @field {string} timestamp when the router received it, as reported
 * @field {string} kind      the message class as reported, "" when absent
 */
export def struct SmsMessage {
    id as string,
    phone as string,
    message as string,
    timestamp as string,
    kind as string
};

/**
 * Read the router's SMS settings.
 *
 * @param {Client} c an open client
 * @return {SmsSettings} the current settings
 * @example
 *   def s as mt.SmsSettings init mt.smsSettings($c);
 *   if ($s.receiveEnabled) { io.printf("storing SMS on %s\n", $s.port); }
 */
export func smsSettings(c as Client) {
    return smsSettingsFromRow(singleRow($c, SMS_PATH));
}

/**
 * Start storing incoming text messages, received on one modem port.
 *
 * Off by default: a router with a SIM will not keep what arrives until
 * you turn this on. The port is the cellular interface the modem
 * presents (`lteInterfaces` lists them - usually "lte1").
 *
 * @param {Client} c    an open client
 * @param {string} port the modem port to receive on (e.g. "lte1")
 * @throws {Error} kind "routeros" on an empty or spaced port name
 * @example
 *   mt.enableSmsReceive($c, "lte1");
 */
export func enableSmsReceive(c as Client, port as string) {
    ensureName($port, "SMS port");
    apiRun($c, SMS_PATH + "/set",
        {"receive-enabled": "yes", "port": strings.trim($port)});
}

/**
 * Stop storing incoming text messages.
 *
 * Messages already in the inbox are kept; only reception stops.
 *
 * @param {Client} c an open client
 * @example
 *   mt.disableSmsReceive($c);
 */
export func disableSmsReceive(c as Client) {
    apiRun($c, SMS_PATH + "/set", {"receive-enabled": "no"});
}

/**
 * Restrict which sender the router will act on, and how many messages
 * it keeps.
 *
 * RouterOS can run commands sent by SMS; `allowedNumber` is the sender
 * whose messages are honoured, so setting it is the difference between
 * "anyone who knows the SIM number can drive this router" and "only
 * this one number can". Pass "" to clear the restriction.
 *
 * @param {Client} c             an open client
 * @param {string} allowedNumber the sender to accept, "" for any
 * @param {int}    keepMaxSms    how many received messages to keep (1-100)
 * @throws {Error} kind "routeros" on a malformed number or a cap outside 1-100
 * @example
 *   mt.restrictSms($c, "+441632960123", 50);
 */
export func restrictSms(c as Client, allowedNumber as string, keepMaxSms as int) {
    if ($keepMaxSms < 1 or $keepMaxSms > 100) {
        raiseError("the kept-message count must be between 1 and 100");
    }
    def number as string init strings.trim($allowedNumber);
    if ($number != "") {
        ensurePhoneNumber($number);
    }
    apiRun($c, SMS_PATH + "/set",
        {"allowed-number": $number, "keep-max-sms": convert.toString($keepMaxSms)});
}

/**
 * Send a text message from the router's modem.
 *
 * The everyday use is alerting from a site whose uplink is exactly what
 * broke - an SMS leaves over the cellular modem when e-mail cannot.
 * Pair it with `netwatch` or the scheduler.
 *
 * @param {Client} c           an open client
 * @param {string} port        the modem port to send through (e.g. "lte1")
 * @param {string} phoneNumber the recipient's number
 * @param {string} message     the message text
 * @throws {Error} kind "routeros" on a bad port, number, or empty message,
 *                 kind "mikrotik" when the modem refuses to send
 * @example
 *   mt.sendSms($c, "lte1", "+441632960123", "gw1: uplink down");
 */
export func sendSms(c as Client, port as string, phoneNumber as string, message as string) {
    ensureName($port, "SMS port");
    def number as string init strings.trim($phoneNumber);
    ensurePhoneNumber($number);
    if ($message == "") {
        raiseError("the message must not be empty");
    }
    apiRun($c, SMS_SEND_COMMAND,
        {"port": strings.trim($port), "phone-number": $number, "message": $message});
}

/**
 * Read the received messages.
 *
 * Empty until `enableSmsReceive` has been called.
 *
 * @param {Client} c an open client
 * @return {list of SmsMessage} the stored messages
 * @example
 *   for (def m in mt.smsInbox($c)) { io.printf("%s: %s\n", $m.phone, $m.message); }
 */
export func smsInbox(c as Client) {
    def rows as list of map of string to string init getAll($c, SMS_INBOX_PATH);
    def out as list of SmsMessage init [];
    for (def row in $rows) {
        $out[] = smsMessageFromRow($row);
    }
    return $out;
}

/**
 * Delete one received message.
 *
 * @param {Client} c  an open client
 * @param {string} id the message id
 * @throws {Error} kind "routeros" on an empty id
 */
export func removeSmsMessage(c as Client, id as string) {
    remove($c, SMS_INBOX_PATH, $id);
}

/**
 * Empty the inbox.
 *
 * @param {Client} c an open client
 * @return {int} how many messages were deleted
 * @example
 *   io.printf("cleared %d messages\n", mt.clearSmsInbox($c));
 */
export func clearSmsInbox(c as Client) {
    def rows as list of map of string to string init getAll($c, SMS_INBOX_PATH);
    def removed as int init 0;
    for (def row in $rows) {
        remove($c, SMS_INBOX_PATH, rowValue($row, ".id"));
        $removed = $removed + 1;
    }
    return $removed;
}

/**
 * Fold a reply row into SmsSettings.
 *
 * @param {map of string to string} row a "/tool/sms/print" row
 * @return {SmsSettings} the typed settings
 * @internal
 */
func smsSettingsFromRow(row as map of string to string) {
    return SmsSettings{
        receiveEnabled: rowBool($row, "receive-enabled"),
        port: rowValue($row, "port"),
        channel: rowValue($row, "channel"),
        allowedNumber: rowValue($row, "allowed-number"),
        keepMaxSms: rowInt($row, "keep-max-sms"),
        autoErase: rowBool($row, "auto-erase")
    };
}

/**
 * Fold a reply row into an SmsMessage.
 *
 * @param {map of string to string} row a "/tool/sms/inbox/print" row
 * @return {SmsMessage} the typed message
 * @internal
 */
func smsMessageFromRow(row as map of string to string) {
    return SmsMessage{
        id: rowValue($row, ".id"),
        phone: rowValue($row, "phone"),
        message: rowValue($row, "message"),
        timestamp: rowValue($row, "timestamp"),
        kind: rowValue($row, "type")
    };
}

/**
 * Validate a phone number: digits plus the usual punctuation.
 *
 * Deliberately lenient - national formats vary - but it catches the
 * common slip of passing a name or an address where a number belongs.
 *
 * @param {string} number the candidate (already trimmed)
 * @throws {Error} kind "routeros" when empty, foreign-charactered, or digitless
 * @internal
 */
func ensurePhoneNumber(number as string) {
    if ($number == "") {
        raiseError("the phone number must not be empty");
    }
    def digits as int init 0;
    def parts as list of string init strings.chars($number);
    for (def ch in $parts) {
        if (not strings.contains(PHONE_CHARS, $ch)) {
            raiseError("\"" + $number + "\" is not a valid phone number");
        }
        if (strings.contains(DIGIT_CHARS, $ch)) {
            $digits = $digits + 1;
        }
    }
    if ($digits == 0) {
        raiseError("\"" + $number + "\" is not a valid phone number - it has no digits");
    }
}
