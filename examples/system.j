#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

/**
 * system example - system info, identity, and updates.
 *
 * Read-only unless noted; mutating calls are shown as comments.
 * Set the router credentials in the environment:
 *   MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/system.j
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

def info as mt.SystemInfo init mt.systemInfo($c);
io.printf("%s: %s on %s (%s), up %s\n",
    mt.identity($c), $info.version, $info.boardName, $info.architecture, $info.uptime);
def rb as mt.Routerboard init mt.routerboard($c);
if ($rb.upgradeAvailable) { io.printf("firmware %s -> %s\n", $rb.currentFirmware, $rb.upgradeFirmware); }
def st as mt.UpdateStatus init mt.checkForUpdates($c);
if ($st.updateAvailable) { io.printf("RouterOS %s -> %s available\n", $st.installedVersion, $st.latestVersion); }
else { io.printf("RouterOS is up to date (%s)\n", $st.installedVersion); }

#   mt.installUpdates($c);          # downloads + reboots
#   mt.reboot($c);

mt.disconnect($c);
