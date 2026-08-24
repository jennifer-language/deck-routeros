# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - containers: run OCI images on the router (RouterOS v7).
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the container list. */
export def const CONTAINER_PATH as string init "/container";

/** RouterOS API path of the container environment-variable lists. */
export def const CONTAINER_ENVS_PATH as string init "/container/envs";

/** RouterOS API path of the container mount lists. */
export def const CONTAINER_MOUNTS_PATH as string init "/container/mounts";

/** RouterOS API path of the container config (registry, temp dir). */
export def const CONTAINER_CONFIG_PATH as string init "/container/config";

/**
 * One container on the router.
 *
 * `name` is the handle you gave it - its `comment` - because RouterOS's
 * own `name` property on a container row is read-only and reports the
 * image tag ("pihole:latest"), not anything you chose. It falls back to
 * that tag only when the container carries no comment.
 *
 * @field {string} id        internal RouterOS id
 * @field {string} name      the handle you gave it (`comment`), else the image tag
 * @field {string} tag       the image tag it runs
 * @field {string} status    "running", "stopped", "extracting", "error", ...
 * @field {bool}   running   true while the container is up
 * @field {string} interfaceName the veth interface it attaches to
 * @field {string} rootDir   where its filesystem lives on the router
 * @field {string} envLists  comma-separated env lists it reads ("" for none)
 * @field {string} mountLists comma-separated mount lists it uses ("" for none)
 */
export def struct Container {
    id as string,
    name as string,
    tag as string,
    status as string,
    running as bool,
    interfaceName as string,
    rootDir as string,
    envLists as string,
    mountLists as string
};

/**
 * One environment variable belonging to a named env list.
 *
 * @field {string} id       internal RouterOS id
 * @field {string} listName the list this variable belongs to
 * @field {string} key      the variable name (e.g. "TZ")
 * @field {string} value    the variable value
 */
export def struct ContainerEnv {
    id as string,
    listName as string,
    key as string,
    value as string
};

/**
 * One mount belonging to a named mount list.
 *
 * @field {string} id       internal RouterOS id
 * @field {string} listName the list this mount belongs to
 * @field {string} src      the path on the router's storage
 * @field {string} dst      the path inside the container
 */
export def struct ContainerMount {
    id as string,
    listName as string,
    src as string,
    dst as string
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
 * container entry itself. Environment variables and mounts are attached
 * separately - build the lists with `addContainerEnv` /
 * `addContainerMount`, point the container at them with
 * `setContainerEnvLists` / `setContainerMountLists`, and do both BEFORE
 * the first `startContainer`, since most images read their config only
 * at startup.
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
 *   mt.addContainerEnv($c, "pihole-env", "TZ", "Europe/Vienna");
 *   mt.addContainerMount($c, "pihole-etc", "usb1/pihole/etc", "/etc/pihole");
 *   mt.addContainer($c, "pihole", "pihole/pihole:latest", "veth1", "usb1/pihole");
 *   mt.setContainerEnvLists($c, "pihole", ["pihole-env"]);
 *   mt.setContainerMountLists($c, "pihole", ["pihole-etc"]);
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
 * List the environment variables defined on the router.
 *
 * @param {Client} c an open client
 * @return {list of ContainerEnv} every variable, across all lists
 */
export func containerEnvs(c as Client) {
    def rows as list of map of string to string init getAll($c, CONTAINER_ENVS_PATH);
    def out as list of ContainerEnv init [];
    for (def row in $rows) {
        $out[] = containerEnvFromRow($row);
    }
    return $out;
}

/**
 * Add one environment variable to a named env list.
 *
 * The list is just a name shared by its entries - RouterOS creates it
 * implicitly with the first variable. Point a container at it with
 * `setContainerEnvLists`, before that container's first start.
 *
 * @param {Client} c        an open client
 * @param {string} listName the env list to add to (e.g. "pihole-env")
 * @param {string} key      the variable name (e.g. "TZ")
 * @param {string} value    the variable value
 * @return {string} the RouterOS id of the new entry
 * @throws {Error} kind "routeros" on an empty list name or key
 * @example
 *   mt.addContainerEnv($c, "pihole-env", "TZ", "Europe/Vienna");
 */
export func addContainerEnv(c as Client, listName as string, key as string, value as string) {
    ensureName($listName, "env list");
    if (strings.trim($key) == "") {
        raiseError("the environment variable name must not be empty (e.g. \"TZ\")");
    }
    return add($c, CONTAINER_ENVS_PATH, {
        "list": $listName,
        "key": strings.trim($key),
        "value": $value
    });
}

/**
 * Delete every environment variable in a named list.
 *
 * Handy before re-adding them, so re-running a provisioning script does
 * not pile up duplicates.
 *
 * @param {Client} c        an open client
 * @param {string} listName the env list to clear
 * @return {int} how many variables were deleted
 * @throws {Error} kind "routeros" on an empty list name
 */
export func removeContainerEnvList(c as Client, listName as string) {
    return removeListEntries($c, CONTAINER_ENVS_PATH, $listName, "env list");
}

/**
 * List the container mounts defined on the router.
 *
 * @param {Client} c an open client
 * @return {list of ContainerMount} every mount, across all lists
 */
export func containerMounts(c as Client) {
    def rows as list of map of string to string init getAll($c, CONTAINER_MOUNTS_PATH);
    def out as list of ContainerMount init [];
    for (def row in $rows) {
        $out[] = containerMountFromRow($row);
    }
    return $out;
}

/**
 * Add one mount to a named mount list.
 *
 * `src` is a path on the router's own storage (it is created if
 * missing), `dst` the path it appears at inside the container. Mounting
 * a container's config directory out onto a disk is how its state
 * survives a re-pull of the image.
 *
 * @param {Client} c        an open client
 * @param {string} listName the mount list to add to (e.g. "pihole-etc")
 * @param {string} src      the path on the router (e.g. "usb1/pihole/etc")
 * @param {string} dst      the path inside the container (e.g. "/etc/pihole")
 * @return {string} the RouterOS id of the new entry
 * @throws {Error} kind "routeros" on an empty list name, source, or destination
 * @example
 *   mt.addContainerMount($c, "pihole-etc", "usb1/pihole/etc", "/etc/pihole");
 */
export func addContainerMount(c as Client, listName as string, src as string, dst as string) {
    ensureName($listName, "mount list");
    if (strings.trim($src) == "") {
        raiseError("the mount source must not be empty (a path on the router, e.g. \"usb1/pihole/etc\")");
    }
    if (strings.trim($dst) == "") {
        raiseError("the mount destination must not be empty (a path inside the container, e.g. \"/etc/pihole\")");
    }
    return add($c, CONTAINER_MOUNTS_PATH, {
        "list": $listName,
        "src": strings.trim($src),
        "dst": strings.trim($dst)
    });
}

/**
 * Delete every mount in a named list.
 *
 * @param {Client} c        an open client
 * @param {string} listName the mount list to clear
 * @return {int} how many mounts were deleted
 * @throws {Error} kind "routeros" on an empty list name
 */
export func removeContainerMountList(c as Client, listName as string) {
    return removeListEntries($c, CONTAINER_MOUNTS_PATH, $listName, "mount list");
}

/**
 * Point a container at the env lists it should read.
 *
 * Replaces whatever it referenced before; an empty list detaches all of
 * them. A running container does not pick this up - set it before the
 * first start, or stop and start it.
 *
 * @param {Client} c         an open client
 * @param {string} name      the container name/comment
 * @param {list of string} listNames the env lists to attach
 * @throws {Error} kind "routeros" when no such container exists
 * @example
 *   mt.setContainerEnvLists($c, "pihole", ["pihole-env"]);
 */
export func setContainerEnvLists(c as Client, name as string, listNames as list of string) {
    def id as string init requiredContainerId($c, $name);
    set($c, CONTAINER_PATH, $id, {"envlists": joinListNames($listNames, "env list")});
}

/**
 * Point a container at the mount lists it should use.
 *
 * Replaces whatever it referenced before; an empty list detaches all of
 * them. Set it before the container's first start.
 *
 * @param {Client} c         an open client
 * @param {string} name      the container name/comment
 * @param {list of string} listNames the mount lists to attach
 * @throws {Error} kind "routeros" when no such container exists
 * @example
 *   mt.setContainerMountLists($c, "pihole", ["pihole-etc"]);
 */
export func setContainerMountLists(c as Client, name as string, listNames as list of string) {
    def id as string init requiredContainerId($c, $name);
    set($c, CONTAINER_PATH, $id, {"mountlists": joinListNames($listNames, "mount list")});
}

/**
 * Delete every entry under a path that belongs to one named list.
 *
 * @param {Client} c        an open client
 * @param {string} path     the env or mount list path
 * @param {string} listName the list to clear
 * @param {string} what     noun for the error message
 * @return {int} how many entries were deleted
 * @throws {Error} kind "routeros" on an empty list name
 * @internal
 */
func removeListEntries(c as Client, path as string, listName as string, what as string) {
    ensureName($listName, $what);
    def rows as list of map of string to string init getAll($c, $path);
    def gone as int init 0;
    for (def row in $rows) {
        if (rowValue($row, "list") == $listName) {
            remove($c, $path, rowValue($row, ".id"));
            $gone = $gone + 1;
        }
    }
    return $gone;
}

/**
 * Validate and join list names into the comma-separated form RouterOS
 * wants in `envlists` / `mountlists`.
 *
 * @param {list of string} listNames the names to join
 * @param {string} what noun for the error message
 * @return {string} the joined names ("" for none)
 * @throws {Error} kind "routeros" on an empty or space-containing name
 * @internal
 */
func joinListNames(listNames as list of string, what as string) {
    for (def name in $listNames) {
        ensureName($name, $what);
    }
    return strings.join($listNames, ",");
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
 * RouterOS reports the live state as a plain `running` bool; older
 * builds send a richer `status` word instead, so each fills in for the
 * other.
 *
 * @param {map of string to string} row a "/container/print" row
 * @return {Container} the typed container
 * @internal
 */
func containerFromRow(row as map of string to string) {
    def label as string init rowValue($row, "comment");
    if ($label == "") {
        $label = rowValue($row, "name");
    }
    def tag as string init rowValue($row, "tag");
    if ($tag == "") {
        $tag = rowValue($row, "name");
    }
    if ($tag == "") {
        $tag = rowValue($row, "remote-image");
    }
    def status as string init rowValue($row, "status");
    def running as bool init rowBool($row, "running") or $status == "running";
    if ($status == "") {
        $status = "stopped";
        if ($running) {
            $status = "running";
        }
    }
    return Container{
        id: rowValue($row, ".id"),
        name: $label,
        tag: $tag,
        status: $status,
        running: $running,
        interfaceName: rowValue($row, "interface"),
        rootDir: rowValue($row, "root-dir"),
        envLists: rowValue($row, "envlists"),
        mountLists: rowValue($row, "mountlists")
    };
}

/**
 * Fold a reply row into a ContainerEnv.
 *
 * @param {map of string to string} row a "/container/envs/print" row
 * @return {ContainerEnv} the typed variable
 * @internal
 */
func containerEnvFromRow(row as map of string to string) {
    return ContainerEnv{
        id: rowValue($row, ".id"),
        listName: rowValue($row, "list"),
        key: rowValue($row, "key"),
        value: rowValue($row, "value")
    };
}

/**
 * Fold a reply row into a ContainerMount.
 *
 * @param {map of string to string} row a "/container/mounts/print" row
 * @return {ContainerMount} the typed mount
 * @internal
 */
func containerMountFromRow(row as map of string to string) {
    return ContainerMount{
        id: rowValue($row, ".id"),
        listName: rowValue($row, "list"),
        src: rowValue($row, "src"),
        dst: rowValue($row, "dst")
    };
}
