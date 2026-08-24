# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - disks: USB / NVMe / SATA storage on the router.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the disk list. */
export def const DISK_PATH as string init "/disk";

def const DISK_FILESYSTEMS as list of string init ["ext4", "fat32", "exfat", "btrfs", "vfat"];

# RouterOS renamed the format command: "/disk/format-drive" on the older
# v7 builds, plain "/disk/format" from 7.21 on (7.21.5 answers the old
# spelling with "no such command"). formatDisk tries the current name and
# falls back, so one call works on both.
def const DISK_FORMAT_COMMAND as string init "/format";
def const DISK_FORMAT_COMMAND_LEGACY as string init "/format-drive";

/**
 * One storage device attached to the router.
 *
 * `name` is what you pass to `diskByName` / `formatDisk` / `ejectDisk`.
 * RouterOS leaves its own `name` property empty on plain USB storage
 * (7.21.5 does, at least) and reports the label everything else calls
 * the disk - "usb1", "usb1-part1" - in `slot` instead, so `name` falls
 * back to `slot` and the lookups accept either.
 *
 * @field {string} id        internal RouterOS id
 * @field {string} name      the device name (e.g. "usb1", "nvme1"), from `slot` when unnamed
 * @field {string} model     the disk model / label as reported
 * @field {string} kind      the device type as reported ("hardware", "partition", "raid", ...)
 * @field {string} fs        the filesystem ("ext4", "fat32", "", ...)
 * @field {int}    sizeBytes total capacity in bytes (0 when not reported)
 * @field {int}    freeBytes free space in bytes (0 when not reported)
 * @field {string} slot      the physical slot / interface as reported
 */
export def struct Disk {
    id as string,
    name as string,
    model as string,
    kind as string,
    fs as string,
    sizeBytes as int,
    freeBytes as int,
    slot as string
};

/**
 * List the storage devices on the router.
 *
 * Returns an empty list on routers with no attached storage. Container
 * root-dirs, backups, and downloaded files all live on these.
 *
 * @param {Client} c an open client
 * @return {list of Disk} all disks
 */
export func disks(c as Client) {
    def out as list of Disk init [];
    def rows as list of map of string to string init [];
    try {
        $rows = getAll($c, DISK_PATH);
    } catch (e) {
        return $out;
    }
    for (def row in $rows) {
        $out[] = diskFromRow($row);
    }
    return $out;
}

/**
 * Look one disk up by its name.
 *
 * Matches RouterOS's own `name` property first and the `slot` label
 * second, so the name `disks(c)` reports always finds the disk again -
 * see the `Disk` struct on why those differ.
 *
 * @param {Client} c    an open client
 * @param {string} name the disk name (e.g. "usb1")
 * @return {Disk} the disk
 * @throws {Error} kind "routeros" when no disk has that name
 */
export func diskByName(c as Client, name as string) {
    def row as map of string to string init diskRowByName($c, $name);
    if (len($row) == 0) {
        raiseError("the disk \"" + $name + "\" was not found on the router");
    }
    return diskFromRow($row);
}

/**
 * Format a storage device - ERASES EVERYTHING ON IT.
 *
 * This is destructive and irreversible: every file, backup, and
 * container filesystem on the disk is gone. There is no undo and no
 * confirmation prompt from this call. Double-check the device name
 * (`disks(c)` / `diskByName`), and never point it at a disk holding
 * data you have not backed up elsewhere.
 *
 * Pick the filesystem for the use: "ext4" for a router-only disk
 * (containers, logs), "exfat"/"fat32" for a disk you also read on a PC.
 *
 * Formatting the whole device ("usb1") and formatting its partition
 * ("usb1-part1") are different targets; a container root-dir lives on
 * the partition.
 *
 * @param {Client} c          an open client
 * @param {string} name       the disk to format
 * @param {string} filesystem "ext4", "fat32", "exfat", "btrfs", or "vfat"
 * @param {string} label      a volume label ("" for none)
 * @throws {Error} kind "routeros" on an unknown disk or filesystem,
 *                 kind "mikrotik" when the format fails
 * @example
 *   mt.formatDisk($c, "usb1", "ext4", "container-storage");
 */
export func formatDisk(c as Client, name as string, filesystem as string, label as string) {
    if (not lists.contains(DISK_FILESYSTEMS, $filesystem)) {
        raiseError("unknown filesystem \"" + $filesystem + "\" - use one of: " + strings.join(DISK_FILESYSTEMS, ", "));
    }
    def id as string init requiredDiskId($c, $name);
    def attrs as map of string to string init {".id": $id, "file-system": $filesystem};
    if (strings.trim($label) != "") {
        $attrs["label"] = $label;
    }
    try {
        apiRun($c, DISK_PATH + DISK_FORMAT_COMMAND, $attrs);
    } catch (e) {
        if (not isUnknownCommand($e.kind, $e.message)) {
            throw $e;
        }
        apiRun($c, DISK_PATH + DISK_FORMAT_COMMAND_LEGACY, $attrs);
    }
}

/**
 * Eject a removable disk so it is safe to unplug.
 *
 * @param {Client} c    an open client
 * @param {string} name the disk to eject
 * @throws {Error} kind "routeros" when no disk has that name
 */
export func ejectDisk(c as Client, name as string) {
    apiRun($c, DISK_PATH + "/eject", {".id": requiredDiskId($c, $name)});
}

/**
 * Resolve a disk name to its RouterOS id.
 *
 * @param {Client} c    an open client
 * @param {string} name the disk name or slot label
 * @return {string} the disk id
 * @throws {Error} kind "routeros" when no disk matches
 * @internal
 */
func requiredDiskId(c as Client, name as string) {
    def row as map of string to string init diskRowByName($c, $name);
    if (len($row) == 0) {
        raiseError("the disk \"" + $name + "\" was not found on the router (neither its name nor its slot matched - `disks(c)` lists what is attached)");
    }
    return rowValue($row, ".id");
}

/**
 * Read the disk table and pick the row for a name.
 *
 * Reads the whole (tiny) table rather than filtering server-side on
 * `?name=`, because the `slot` fallback needs both properties.
 *
 * @param {Client} c    an open client
 * @param {string} name the disk name or slot label
 * @return {map of string to string} the matching row, or an empty map
 * @throws {Error} kind "routeros" on an empty name
 * @internal
 */
func diskRowByName(c as Client, name as string) {
    ensureName($name, "disk");
    return diskRowMatching(getAll($c, DISK_PATH), $name);
}

/**
 * Pick the disk row whose `name` - or, failing that, whose `slot` -
 * matches.
 *
 * @param {list of map of string to string} rows "/disk/print" rows
 * @param {string} name the disk name or slot label
 * @return {map of string to string} the matching row, or an empty map
 * @internal
 */
func diskRowMatching(rows as list of map of string to string, name as string) {
    def row as map of string to string init findRowByField($rows, "name", $name);
    if (len($row) > 0) {
        return $row;
    }
    return findRowByField($rows, "slot", $name);
}

/**
 * Tell a "the router has no such command" refusal from a real failure.
 *
 * Used to fall back to a command's older spelling without swallowing a
 * genuine error (a busy disk, a refused format).
 *
 * @param {string} kind    the error kind
 * @param {string} message the error message
 * @return {bool} true when the router did not recognise the command
 * @internal
 */
func isUnknownCommand(kind as string, message as string) {
    if ($kind != "mikrotik") {
        return false;
    }
    return strings.contains(strings.lower($message), "no such command");
}

/**
 * Fold a reply row into a Disk.
 *
 * @param {map of string to string} row a "/disk/print" row
 * @return {Disk} the typed disk
 * @internal
 */
func diskFromRow(row as map of string to string) {
    def label as string init rowValue($row, "name");
    if ($label == "") {
        $label = rowValue($row, "slot");
    }
    return Disk{
        id: rowValue($row, ".id"),
        name: $label,
        model: rowValue($row, "disk"),
        kind: rowValue($row, "type"),
        fs: rowValue($row, "fs"),
        sizeBytes: rowInt($row, "size"),
        freeBytes: rowInt($row, "free"),
        slot: rowValue($row, "slot")
    };
}
