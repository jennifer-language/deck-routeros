# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - containers: run OCI images on the router (RouterOS v7).
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the container list. */
export def const CONTAINER_PATH as string init "/container";

/** RouterOS API path of the container environment-variable list. */
export def const CONTAINER_ENVS_PATH as string init "/container/envs";

/** RouterOS API path of the container config (registry, temp dir). */
export def const CONTAINER_CONFIG_PATH as string init "/container/config";

/**
 * One container on the router.
 *
 * @field {string} id        internal RouterOS id
 * @field {string} name      the container name (from `comment`/`name`)
 * @field {string} tag       the image tag it runs
 * @field {string} status    "running", "stopped", "extracting", "error", ...
 * @field {bool}   running   computed: the status equals "running"
 * @field {string} interfaceName the veth interface it attaches to
 * @field {string} rootDir   where its filesystem lives on the router
 */
export def struct Container {
    id as string,
    name as string,
    tag as string,
    status as string,
    running as bool,
    interfaceName as string,
    rootDir as string
};

/**
 * List the containers on the router.
 *
 * @param {Client} c an open client
 * @return {list of Container} all containers
 */
export func containers(c as Client) {
    def rows as list of map of string to string init getAll($c, CONTAINER_PATH);
    def out as list of Container init [];
    for (def row in $rows) {
        $out[] = containerFromRow($row);
    }
    return $out;
}

/**
 * Add a container from a registry image.
 *
 * RouterOS pulls the image (from `remote-image`, e.g.
 * "pihole/pihole:latest"), extracts it into `rootDir` on the router's
 * storage, and attaches it to an existing veth interface for
 * networking. Containers are OFF by default and must be enabled in the
 * device settings first (`/container/config` and the `container`
 * package + a `devel`-signed enable) - a deliberate safety gate this
 * call does not bypass. The image is only fetched on `startContainer`.
 *
 * Networking (the veth), storage (`rootDir`), and enablement are
 * prerequisites you set up first (generic verbs); this call creates the
 * container entry itself.
 *
 * @param {Client} c             an open client
 * @param {string} name          a name/comment for the container
 * @param {string} remoteImage   the registry image (e.g. "pihole/pihole:latest")
 * @param {string} interfaceName the veth interface to attach
 * @param {string} rootDir       the filesystem path on the router (e.g. "usb1/pihole")
 * @return {string} the RouterOS id of the container
 * @throws {Error} kind "routeros" on bad input or an unknown interface
 * @example
 *   # prerequisites (generic verbs): a veth, and container support enabled
 *   mt.add($c, "/interface/veth", {"name": "veth1", "address": "172.17.0.2/24",
 *       "gateway": "172.17.0.1"});
 *   mt.addContainer($c, "pihole", "pihole/pihole:latest", "veth1", "usb1/pihole");
 *   mt.startContainer($c, "pihole");
 */
export func addContainer(c as Client, name as string, remoteImage as string, interfaceName as string, rootDir as string) {
    ensureName($name, "container");
    if (strings.trim($remoteImage) == "") {
        raiseError("the remote image must not be empty (e.g. \"pihole/pihole:latest\")");
    }
    requiredId($c, INTERFACE_PATH, $interfaceName, "veth interface");
    if (strings.trim($rootDir) == "") {
        raiseError("the root directory must not be empty (e.g. \"usb1/pihole\")");
    }
    return add($c, CONTAINER_PATH, {
        "remote-image": strings.trim($remoteImage),
        "interface": $interfaceName,
        "root-dir": strings.trim($rootDir),
        "comment": $name
    });
}

/**
 * Start a container (pulls the image on first run).
 *
 * @param {Client} c    an open client
 * @param {string} name the container name/comment
 * @throws {Error} kind "routeros" when no such container exists
 */
export func startContainer(c as Client, name as string) {
    apiRun($c, CONTAINER_PATH + "/start", {".id": requiredContainerId($c, $name)});
}

/**
 * Stop a container.
 *
 * @param {Client} c    an open client
 * @param {string} name the container name/comment
 * @throws {Error} kind "routeros" when no such container exists
 */
export func stopContainer(c as Client, name as string) {
    apiRun($c, CONTAINER_PATH + "/stop", {".id": requiredContainerId($c, $name)});
}

/**
 * Remove a container (its extracted filesystem goes too).
 *
 * @param {Client} c    an open client
 * @param {string} name the container name/comment
 * @throws {Error} kind "routeros" when no such container exists
 */
export func removeContainer(c as Client, name as string) {
    remove($c, CONTAINER_PATH, requiredContainerId($c, $name));
}

/**
 * Resolve a container name/comment to its id.
 *
 * @param {Client} c    an open client
 * @param {string} name the container name/comment
 * @return {string} the container id
 * @throws {Error} kind "routeros" when no such container exists
 * @internal
 */
func requiredContainerId(c as Client, name as string) {
    def rows as list of map of string to string init getAll($c, CONTAINER_PATH);
    for (def row in $rows) {
        if (rowValue($row, "comment") == $name or rowValue($row, "name") == $name) {
            return rowValue($row, ".id");
        }
    }
    raiseError("no container named \"" + $name + "\" was found");
}

/**
 * Fold a reply row into a Container.
 *
 * @param {map of string to string} row a "/container/print" row
 * @return {Container} the typed container
 * @internal
 */
func containerFromRow(row as map of string to string) {
    def status as string init rowValue($row, "status");
    def label as string init rowValue($row, "name");
    if ($label == "") {
        $label = rowValue($row, "comment");
    }
    return Container{
        id: rowValue($row, ".id"),
        name: $label,
        tag: rowValue($row, "tag"),
        status: $status,
        running: $status == "running",
        interfaceName: rowValue($row, "interface"),
        rootDir: rowValue($row, "root-dir")
    };
}
