# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - white-box tests for the system topic.
# Spliced into routeros_test.j via include - run with:
#   jennifer test src/routeros_test.j

func testPackageFromRow() {
    def row as map of string to string init {
        ".id": "*1",
        "name": "routeros",
        "version": "7.15.2",
        "disabled": "false"
    };
    def p as Package init packageFromRow($row);
    testing.assertEqual($p.id, "*1");
    testing.assertEqual($p.name, "routeros");
    testing.assertEqual($p.version, "7.15.2");
    testing.assertFalse($p.disabled);
}

func testUpdateStatusNewerVersionAvailable() {
    def row as map of string to string init {
        "channel": "stable",
        "installed-version": "7.15.2",
        "latest-version": "7.16",
        "status": "New version is available"
    };
    def st as UpdateStatus init updateStatusFromRow($row);
    testing.assertEqual($st.channel, "stable");
    testing.assertEqual($st.installedVersion, "7.15.2");
    testing.assertEqual($st.latestVersion, "7.16");
    testing.assertEqual($st.status, "New version is available");
    testing.assertTrue($st.updateAvailable);
}

func testUpdateStatusAlreadyCurrent() {
    def row as map of string to string init {
        "channel": "stable",
        "installed-version": "7.16",
        "latest-version": "7.16",
        "status": "System is already up to date"
    };
    def st as UpdateStatus init updateStatusFromRow($row);
    testing.assertFalse($st.updateAvailable);
}

func testUpdateStatusUnknownLatestIsNotAvailable() {
    def row as map of string to string init {
        "installed-version": "7.15.2",
        "status": "ERROR: could not resolve dns name"
    };
    def st as UpdateStatus init updateStatusFromRow($row);
    testing.assertEqual($st.latestVersion, "");
    testing.assertFalse($st.updateAvailable);
}

func testRouterboardFromRowUpgradePending() {
    def row as map of string to string init {
        "model": "RB4011iGS+",
        "serial-number": "ABCDEF123456",
        "firmware-type": "al2",
        "current-firmware": "7.15.1",
        "upgrade-firmware": "7.15.2"
    };
    def rb as Routerboard init routerboardFromRow($row);
    testing.assertEqual($rb.model, "RB4011iGS+");
    testing.assertEqual($rb.serialNumber, "ABCDEF123456");
    testing.assertEqual($rb.firmwareType, "al2");
    testing.assertEqual($rb.currentFirmware, "7.15.1");
    testing.assertEqual($rb.upgradeFirmware, "7.15.2");
    testing.assertTrue($rb.upgradeAvailable);
}

func testRouterboardFromRowFirmwareCurrent() {
    def row as map of string to string init {
        "model": "hAP ac^2",
        "current-firmware": "7.15.2",
        "upgrade-firmware": "7.15.2"
    };
    def rb as Routerboard init routerboardFromRow($row);
    testing.assertFalse($rb.upgradeAvailable);
}

func testRouterboardFromRowUnknownFirmware() {
    def row as map of string to string init {"model": "CHR"};
    def rb as Routerboard init routerboardFromRow($row);
    testing.assertEqual($rb.currentFirmware, "");
    testing.assertFalse($rb.upgradeAvailable);
}

func testSystemInfoFromRow() {
    def row as map of string to string init {
        "version": "7.15.2 (stable)",
        "board-name": "RB4011iGS+",
        "architecture-name": "arm64",
        "uptime": "2w3d4h5m6s",
        "cpu-load": "4",
        "free-memory": "845611008",
        "total-memory": "1073741824"
    };
    def info as SystemInfo init systemInfoFromRow($row);
    testing.assertEqual($info.version, "7.15.2 (stable)");
    testing.assertEqual($info.boardName, "RB4011iGS+");
    testing.assertEqual($info.architecture, "arm64");
    testing.assertEqual($info.uptime, "2w3d4h5m6s");
    testing.assertEqual($info.cpuLoad, "4");
    testing.assertEqual($info.freeMemory, "845611008");
    testing.assertEqual($info.totalMemory, "1073741824");
}
