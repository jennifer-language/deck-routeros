# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - disks: USB / NVMe / SATA storage on the router.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the disk list. */
export def const DISK_PATH as string init "/disk";

def const DISK_FILESYSTEMS as list of string init ["ext4", "fat32", "exfat", "btrfs", "vfat"];

/**
 * One storage device attached to the router.
 *
 * @field {string} id        internal RouterOS id
 * @field {string} name      the device name (e.g. "usb1", "nvme1")
 * @field {string} model     the disk model / label as reported
 * @field {string} kind      the device type as reported ("hardware", "raid", ...)
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
 * @param {Client} c    an open client
 * @param {string} name the disk name (e.g. "usb1")
 * @return {Disk} the disk
 * @throws {Error} kind "routeros" when no disk has that name
 */
export func diskByName(c as Client, name as string) {
    def row as map of string to string init findByName($c, DISK_PATH, $name);
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
    def id as string init requiredId($c, DISK_PATH, $name, "disk");
    def attrs as map of string to string init {".id": $id, "file-system": $filesystem};
    if (strings.trim($label) != "") {
        $attrs["label"] = $label;
    }
    mikrotik.run($c.session, DISK_PATH + "/format-drive", $attrs);
}

/**
 * Eject a removable disk so it is safe to unplug.
 *
 * @param {Client} c    an open client
 * @param {string} name the disk to eject
 * @throws {Error} kind "routeros" when no disk has that name
 */
export func ejectDisk(c as Client, name as string) {
    def id as string init requiredId($c, DISK_PATH, $name, "disk");
    mikrotik.run($c.session, DISK_PATH + "/eject", {".id": $id});
}

/**
 * Fold a reply row into a Disk.
 *
 * @param {map of string to string} row a "/disk/print" row
 * @return {Disk} the typed disk
 * @internal
 */
func diskFromRow(row as map of string to string) {
    return Disk{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        model: rowValue($row, "disk"),
        kind: rowValue($row, "type"),
        fs: rowValue($row, "fs"),
        sizeBytes: rowInt($row, "size"),
        freeBytes: rowInt($row, "free"),
        slot: rowValue($row, "slot")
    };
}
