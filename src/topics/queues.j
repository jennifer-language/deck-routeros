# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - simple queues: bandwidth limiting.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the simple-queue list (bandwidth limits). */
export def const QUEUE_SIMPLE_PATH as string init "/queue/simple";

/** RouterOS API path of the queue tree (hierarchical QoS). */
export def const QUEUE_TREE_PATH as string init "/queue/tree";

def const RATE_SUFFIX_CHARS as string init "kKmMgG";

/**
 * One simple queue: a bandwidth limit on a target.
 *
 * Upload is traffic FROM the target (towards the internet), download is
 * traffic TO the target. Rates read like "10M" (10 megabits/s), "512k",
 * "1G"; "0" means unlimited.
 *
 * @field {string} id          internal RouterOS id
 * @field {string} name        queue name
 * @field {string} target      who is limited: address, network, or interface
 *                             (comma-separated when several)
 * @field {string} maxUpload   upload ceiling (e.g. "10M", "0" = unlimited)
 * @field {string} maxDownload download ceiling (e.g. "20M", "0" = unlimited)
 * @field {bool}   dynamic     true when something else (e.g. PPPoE) created it
 * @field {bool}   disabled    true when the queue is switched off
 * @field {string} comment     free-text comment, "" when unset
 */
export def struct SimpleQueue {
    id as string,
    name as string,
    target as string,
    maxUpload as string,
    maxDownload as string,
    dynamic as bool,
    disabled as bool,
    comment as string
};

/**
 * List every simple queue on the router.
 *
 * @param {Client} c an open client
 * @return {list of SimpleQueue} all simple queues
 */
export func simpleQueues(c as Client) {
    def rows as list of map of string to string init getAll($c, QUEUE_SIMPLE_PATH);
    def out as list of SimpleQueue init [];
    for (def row in $rows) {
        $out[] = simpleQueueFromRow($row);
    }
    return $out;
}

/**
 * Cap the bandwidth of a device, a network, or an interface.
 *
 * Creates a simple queue. The target may be one IP address
 * ("192.168.88.50"), a network ("192.168.88.0/24"), an interface name,
 * or a comma-separated mix. Rates are written like "10M" (10
 * megabits/s), "512k", "1G", or plain bits/s ("2500000"); "0" leaves
 * that direction unlimited. Upload is traffic FROM the target, download
 * is traffic TO it.
 *
 * @param {Client} c        an open client
 * @param {string} name     name for the queue; also the handle for
 *                          `setBandwidthLimit` / `removeSimpleQueue`
 * @param {string} target   who to limit
 * @param {string} upload   upload ceiling (e.g. "5M")
 * @param {string} download download ceiling (e.g. "20M")
 * @return {string} the RouterOS id of the new queue
 * @throws {Error} kind "routeros" on a bad name, target, or rate
 * @example
 *   mt.limitBandwidth($c, "guest-wifi", "192.168.90.0/24", "5M", "20M");
 */
export func limitBandwidth(c as Client, name as string, target as string, upload as string, download as string) {
    ensureName($name, "queue");
    def tgt as string init normalizedQueueTarget($c, $target);
    def maxLimit as string init normalizedRate($upload) + "/" + normalizedRate($download);
    return add($c, QUEUE_SIMPLE_PATH, {"name": $name, "target": $tgt, "max-limit": $maxLimit});
}

/**
 * Change the bandwidth cap of an existing simple queue.
 *
 * @param {Client} c        an open client
 * @param {string} name     the queue's name
 * @param {string} upload   new upload ceiling (e.g. "10M", "0" = unlimited)
 * @param {string} download new download ceiling
 * @throws {Error} kind "routeros" on a bad rate or an unknown queue
 */
export func setBandwidthLimit(c as Client, name as string, upload as string, download as string) {
    def maxLimit as string init normalizedRate($upload) + "/" + normalizedRate($download);
    set($c, QUEUE_SIMPLE_PATH, requiredId($c, QUEUE_SIMPLE_PATH, $name, "simple queue"), {"max-limit": $maxLimit});
}

/**
 * Delete a simple queue: the target's bandwidth is no longer limited.
 *
 * @param {Client} c    an open client
 * @param {string} name the queue's name
 * @throws {Error} kind "routeros" when no queue has that name
 */
export func removeSimpleQueue(c as Client, name as string) {
    remove($c, QUEUE_SIMPLE_PATH, requiredId($c, QUEUE_SIMPLE_PATH, $name, "simple queue"));
}

/**
 * Switch a simple queue on.
 *
 * @param {Client} c    an open client
 * @param {string} name the queue's name
 * @throws {Error} kind "routeros" when no queue has that name
 */
export func enableSimpleQueue(c as Client, name as string) {
    enable($c, QUEUE_SIMPLE_PATH, requiredId($c, QUEUE_SIMPLE_PATH, $name, "simple queue"));
}

/**
 * Switch a simple queue off; the limit pauses until enabled again.
 *
 * @param {Client} c    an open client
 * @param {string} name the queue's name
 * @throws {Error} kind "routeros" when no queue has that name
 */
export func disableSimpleQueue(c as Client, name as string) {
    disable($c, QUEUE_SIMPLE_PATH, requiredId($c, QUEUE_SIMPLE_PATH, $name, "simple queue"));
}

/**
 * Validate and normalize one rate value.
 *
 * Accepts digits with an optional single k / M / G suffix, any case,
 * surrounding whitespace tolerated. Normalizes the suffix to RouterOS's
 * canonical spelling (lowercase k, uppercase M and G). "0" is a valid
 * rate and means unlimited.
 *
 * @param {string} rate the candidate (e.g. "10M", "512k", "2500000")
 * @return {string} the normalized rate
 * @throws {Error} kind "routeros" on anything else
 * @internal
 */
func normalizedRate(rate as string) {
    def r as string init strings.trim($rate);
    if ($r == "") {
        raiseError("the rate must not be empty - write it like \"10M\" or \"512k\"");
    }
    def digits as string init "";
    def suffix as string init "";
    def chars as list of string init strings.chars($r);
    for (def ch in $chars) {
        if (strings.contains(DIGIT_CHARS, $ch)) {
            if ($suffix != "") {
                raiseError("\"" + $rate + "\" is not a rate - digits must come before the k/M/G suffix");
            }
            $digits = $digits + $ch;
        } elseif (strings.contains(RATE_SUFFIX_CHARS, $ch)) {
            if ($suffix != "" or $digits == "") {
                raiseError("\"" + $rate + "\" is not a rate - write it like \"10M\" or \"512k\"");
            }
            $suffix = $ch;
        } else {
            raiseError("\"" + $rate + "\" is not a rate - write it like \"10M\" or \"512k\"");
        }
    }
    if ($digits == "") {
        raiseError("\"" + $rate + "\" is not a rate - write it like \"10M\" or \"512k\"");
    }
    if ($suffix == "k" or $suffix == "K") {
        $suffix = "k";
    } elseif ($suffix == "m" or $suffix == "M") {
        $suffix = "M";
    } elseif ($suffix == "g" or $suffix == "G") {
        $suffix = "G";
    }
    return $digits + $suffix;
}

/**
 * Split a RouterOS "max-limit" pair into its halves.
 *
 * "10M/20M" -> upload "10M", download "20M". A value without a slash
 * counts for both directions; "" stays "".
 *
 * @param {string} maxLimit the reported "max-limit" value
 * @return {list of string} two elements: upload, download
 * @internal
 */
func rateHalves(maxLimit as string) {
    def out as list of string init [];
    if (strings.contains($maxLimit, "/")) {
        def parts as list of string init strings.split($maxLimit, "/");
        $out[] = $parts[0];
        $out[] = $parts[1];
    } else {
        $out[] = $maxLimit;
        $out[] = $maxLimit;
    }
    return $out;
}

/**
 * Classify one queue-target entry.
 *
 * @param {string} entry a single target (no commas)
 * @return {string} "cidr", "address", or "name"
 * @throws {Error} kind "routeros" on a malformed CIDR or an empty /
 *                 space-containing name
 * @internal
 */
func targetKind(entry as string) {
    if (strings.contains($entry, "/")) {
        ensureCidr($entry);
        return "cidr";
    }
    if (isIpAddress($entry)) {
        return "address";
    }
    ensureName($entry, "queue target");
    return "name";
}

/**
 * Validate and normalize a queue target list; interface-name entries
 * are checked against the router.
 *
 * @param {Client} c      an open client
 * @param {string} target address / CIDR / interface entries, comma-separated
 * @return {string} the normalized target list
 * @throws {Error} kind "routeros" on an empty entry, a malformed
 *                 address, or an unknown interface
 * @internal
 */
func normalizedQueueTarget(c as Client, target as string) {
    def parts as list of string init strings.split($target, ",");
    def ifaceRows as list of map of string to string init getAll($c, INTERFACE_PATH);
    def out as list of string init [];
    for (def part in $parts) {
        def p as string init strings.trim($part);
        if ($p == "") {
            raiseError("the queue target \"" + $target + "\" must not contain empty entries");
        }
        if (targetKind($p) == "name" and len(findRowByField($ifaceRows, "name", $p)) == 0) {
            raiseError("the queue target interface \"" + $p + "\" was not found on the router");
        }
        $out[] = $p;
    }
    return strings.join($out, ",");
}

/**
 * Fold a reply row into a SimpleQueue.
 *
 * @param {map of string to string} row a "/queue/simple/print" row
 * @return {SimpleQueue} the typed queue
 * @internal
 */
func simpleQueueFromRow(row as map of string to string) {
    def halves as list of string init rateHalves(rowValue($row, "max-limit"));
    return SimpleQueue{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        target: rowValue($row, "target"),
        maxUpload: $halves[0],
        maxDownload: $halves[1],
        dynamic: rowBool($row, "dynamic"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * One queue-tree node: a branch of the QoS hierarchy.
 *
 * @field {string} id         internal RouterOS id
 * @field {string} name       node name
 * @field {string} parent     an interface, "global", or another node's name
 * @field {string} packetMark the mangle mark(s) this node serves, "" on inner nodes
 * @field {string} limitAt    guaranteed rate ("" = none)
 * @field {string} maxLimit   ceiling rate ("" = unlimited)
 * @field {int}    priority   1 (first served) to 8 (last), 0 when unset
 * @field {bool}   disabled   true when switched off
 * @field {string} comment    free-text comment, "" when unset
 */
export def struct TreeQueue {
    id as string,
    name as string,
    parent as string,
    packetMark as string,
    limitAt as string,
    maxLimit as string,
    priority as int,
    disabled as bool,
    comment as string
};

/**
 * List the queue tree.
 *
 * @param {Client} c an open client
 * @return {list of TreeQueue} all nodes
 */
export func treeQueues(c as Client) {
    def rows as list of map of string to string init getAll($c, QUEUE_TREE_PATH);
    def out as list of TreeQueue init [];
    for (def row in $rows) {
        $out[] = treeQueueFromRow($row);
    }
    return $out;
}

/**
 * Plant the root of a QoS hierarchy on an interface.
 *
 * The root's max-limit is the whole game: set it slightly BELOW the
 * real line rate (e.g. "95M" on a 100M line), so the queue - not the
 * modem across the street - is where packets wait. Children then share
 * that budget. Idempotent by name.
 *
 * @param {Client} c        an open client
 * @param {string} name     name for the root (e.g. "qosdown")
 * @param {string} parent   where to shape: an interface name for its
 *                          egress (e.g. "pppoewan" shapes upload,
 *                          "brlan" shapes download), or "global"
 * @param {string} maxLimit the total budget (e.g. "95M")
 * @return {string} the RouterOS id of the root node
 * @throws {Error} kind "routeros" on a bad name, parent, or rate
 * @example
 *   mt.addQueueTreeRoot($c, "qosup", "pppoewan", "38M");
 */
export func addQueueTreeRoot(c as Client, name as string, parent as string, maxLimit as string) {
    ensureName($name, "queue tree node");
    def target as string init strings.trim($parent);
    if ($target != "global") {
        requiredId($c, INTERFACE_PATH, $target, "interface");
    }
    def ceiling as string init normalizedRate($maxLimit);
    def existing as string init idByName($c, QUEUE_TREE_PATH, $name);
    if ($existing != "") {
        return $existing;
    }
    return add($c, QUEUE_TREE_PATH,
        {"name": $name, "parent": $target, "max-limit": $ceiling});
}

/**
 * Hang a traffic class under a tree node.
 *
 * The child serves one packet mark (created with the mangle topic's
 * `setupPacketMark` - a mark no mangle rule sets is refused, because a
 * tree matching phantom marks is the classic silent QoS failure).
 * `limitAt` is the guaranteed share when the line is full; `maxLimit`
 * the ceiling when it is not; `priority` breaks ties between siblings
 * (1 first). Idempotent by name.
 *
 * @param {Client} c          an open client
 * @param {string} name       name for the class (e.g. "qosupvoip")
 * @param {string} parentName the tree node above it (e.g. the root)
 * @param {string} packetMark the mangle packet mark to serve
 * @param {string} limitAt    guaranteed rate (e.g. "5M"; "0" for none)
 * @param {string} maxLimit   ceiling rate (e.g. "38M" to allow the whole line)
 * @param {int}    priority   1-8, lower is served first
 * @return {string} the RouterOS id of the class
 * @throws {Error} kind "routeros" on bad input, an unknown parent
 *                 node, or a mark no mangle rule creates
 * @example
 *   mt.addQueueTreeChild($c, "qosupvoip", "qosup", "voip", "5M", "38M", 1);
 *   mt.addQueueTreeChild($c, "qosuprest", "qosup", "bulk", "10M", "38M", 8);
 */
export func addQueueTreeChild(c as Client, name as string, parentName as string, packetMark as string, limitAt as string, maxLimit as string, priority as int) {
    ensureName($name, "queue tree node");
    ensureName($packetMark, "packet mark");
    ensureTreePriority($priority);
    requiredId($c, QUEUE_TREE_PATH, $parentName, "queue tree node");
    def mangleRows as list of map of string to string init getAll($c, MANGLE_PATH);
    def marker as map of string to string init
        findRowByField($mangleRows, "new-packet-mark", $packetMark);
    if (len($marker) == 0) {
        raiseError("no mangle rule creates the packet mark \"" + $packetMark
            + "\" - set it up first (setupPacketMark)");
    }
    def guaranteed as string init normalizedRate($limitAt);
    def ceiling as string init normalizedRate($maxLimit);
    def existing as string init idByName($c, QUEUE_TREE_PATH, $name);
    if ($existing != "") {
        return $existing;
    }
    return add($c, QUEUE_TREE_PATH, {
        "name": $name,
        "parent": $parentName,
        "packet-mark": $packetMark,
        "limit-at": $guaranteed,
        "max-limit": $ceiling,
        "priority": convert.toString($priority)
    });
}

/**
 * Remove a tree node AND everything hanging under it.
 *
 * Children are removed first, so no orphaned branches remain.
 *
 * @param {Client} c    an open client
 * @param {string} name the node to remove (the root removes the whole tree)
 * @throws {Error} kind "routeros" when no tree node has that name
 */
export func removeTreeQueue(c as Client, name as string) {
    def rows as list of map of string to string init getAll($c, QUEUE_TREE_PATH);
    def ids as list of string init treeQueueFamily($rows, $name);
    if (len($ids) == 0) {
        raiseError("no queue tree node named \"" + $name + "\" was found");
    }
    for (def id in $ids) {
        remove($c, QUEUE_TREE_PATH, $id);
    }
}

/**
 * Switch a tree node on.
 *
 * @param {Client} c    an open client
 * @param {string} name the node's name
 * @throws {Error} kind "routeros" when no tree node has that name
 */
export func enableTreeQueue(c as Client, name as string) {
    enable($c, QUEUE_TREE_PATH, requiredId($c, QUEUE_TREE_PATH, $name, "queue tree node"));
}

/**
 * Switch a tree node off (its subtree stops shaping).
 *
 * @param {Client} c    an open client
 * @param {string} name the node's name
 * @throws {Error} kind "routeros" when no tree node has that name
 */
export func disableTreeQueue(c as Client, name as string) {
    disable($c, QUEUE_TREE_PATH, requiredId($c, QUEUE_TREE_PATH, $name, "queue tree node"));
}

/**
 * Validate a queue-tree priority.
 *
 * @param {int} priority the candidate
 * @throws {Error} kind "routeros" when outside 1-8
 * @internal
 */
func ensureTreePriority(priority as int) {
    if ($priority < 1 or $priority > 8) {
        raiseError("the priority must be between 1 (served first) and 8 (served last)");
    }
}

/**
 * The ids of a node and all its descendants, children before parents.
 *
 * @param {list of map of string to string} rows "/queue/tree/print" rows
 * @param {string} name the top node's name
 * @return {list of string} ids in safe removal order; empty when the
 *         name matches nothing
 * @internal
 */
func treeQueueFamily(rows as list of map of string to string, name as string) {
    def names as list of string init [$name];
    def grew as bool init true;
    while ($grew) {
        $grew = false;
        for (def row in $rows) {
            def rowName as string init rowValue($row, "name");
            if ($rowName != ""
                    and lists.contains($names, rowValue($row, "parent"))
                    and not lists.contains($names, $rowName)) {
                $names[] = $rowName;
                $grew = true;
            }
        }
    }
    def ids as list of string init [];
    for (def i as int init len($names) - 1; $i >= 0; $i = $i - 1) {
        for (def row in $rows) {
            if (rowValue($row, "name") == $names[$i]) {
                $ids[] = rowValue($row, ".id");
            }
        }
    }
    return $ids;
}

/**
 * Fold a reply row into a TreeQueue.
 *
 * @param {map of string to string} row a "/queue/tree/print" row
 * @return {TreeQueue} the typed node
 * @internal
 */
func treeQueueFromRow(row as map of string to string) {
    return TreeQueue{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        parent: rowValue($row, "parent"),
        packetMark: rowValue($row, "packet-mark"),
        limitAt: rowValue($row, "limit-at"),
        maxLimit: rowValue($row, "max-limit"),
        priority: rowInt($row, "priority"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}
