pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    property int refCount: 0

    property bool sysupdateAvailable: false

    property var availableUpdates: []
    property bool isChecking: false
    property bool isUpgrading: false
    property bool hasError: false
    property string errorMessage: ""
    property string errorCode: ""
    property var backends: []
    property string distribution: ""
    property string distributionPretty: ""
    property string pkgManager: ""
    property bool distributionSupported: false
    property var recentLog: []
    property real progress: 0.0
    readonly property int progressPercent: Math.round(progress * 100)
    property string statusStep: ""
    property string currentItem: ""
    property int intervalSeconds: 1800
    property int lastCheckUnix: 0
    property int nextCheckUnix: 0

    readonly property int updateCount: availableUpdates.length
    readonly property bool helperAvailable: sysupdateAvailable && backends.length > 0

    Connections {
        target: HYPEService
        function onCapabilitiesReceived() {
            root.checkCapabilities();
        }
        function onConnectionStateChanged() {
            if (HYPEService.isConnected) {
                root.checkCapabilities();
            } else {
                root.sysupdateAvailable = false;
            }
        }
        function onSysupdateStateUpdate(data) {
            root._applyState(data);
        }
    }

    Component.onCompleted: {
        if (HYPEService.hypeAvailable) {
            checkCapabilities();
        }
    }

    function checkCapabilities() {
        if (!HYPEService.capabilities || !Array.isArray(HYPEService.capabilities)) {
            sysupdateAvailable = false;
            return;
        }
        const has = HYPEService.capabilities.includes("sysupdate");
        if (has && !sysupdateAvailable) {
            sysupdateAvailable = true;
            requestState();
        } else if (!has) {
            sysupdateAvailable = false;
        }
    }

    function requestState() {
        if (!HYPEService.isConnected || !sysupdateAvailable) {
            return;
        }
        HYPEService.sysupdateGetState(resp => {
            if (resp && resp.result) {
                _applyState(resp.result);
            }
        });
    }

    function _applyState(data) {
        if (!data) {
            return;
        }
        availableUpdates = data.packages || [];
        backends = data.backends || [];
        distribution = data.distro || "";
        distributionPretty = data.distroPretty || "";
        distributionSupported = (backends.length > 0);
        recentLog = data.recentLog || [];
        intervalSeconds = data.intervalSeconds || 1800;
        lastCheckUnix = data.lastCheckUnix || 0;
        nextCheckUnix = data.nextCheckUnix || 0;

        const phase = data.phase || "idle";
        switch (phase) {
        case "refreshing":
            isChecking = true;
            isUpgrading = false;
            break;
        case "upgrading":
            isChecking = false;
            isUpgrading = true;
            break;
        default:
            isChecking = false;
            isUpgrading = false;
        }

        if (data.error) {
            hasError = true;
            errorMessage = data.error.message || "";
            errorCode = data.error.code || "";
        } else {
            hasError = false;
            errorMessage = "";
            errorCode = "";
        }

        if (isUpgrading) {
            if (data.progress !== undefined && data.progress > 0) {
                progress = Math.min(1.0, Math.max(0.0, data.progress / 100.0));
            } else {
                progress = _computeProgressFromLog(recentLog);
            }
            statusStep = data.statusStep || _computeStepFromLog(recentLog);
            currentItem = data.currentItem || "";
        } else if (isChecking) {
            progress = 0.0;
            statusStep = I18n.tr("Checking for updates…");
            currentItem = "";
        } else {
            progress = hasError ? 0.0 : 1.0;
            statusStep = hasError ? I18n.tr("Update error") : I18n.tr("Everything is up to date");
            currentItem = "";
        }

        if (backends.length > 0) {
            const sys = backends.find(b => b.repo === "system" || b.repo === "ostree");
            pkgManager = sys ? sys.id : backends[0].id;
        } else {
            pkgManager = "";
        }
    }

    function _computeProgressFromLog(lines) {
        if (!lines || lines.length === 0)
            return 0.06;
        for (let i = lines.length - 1; i >= 0; i--) {
            const line = String(lines[i]).trim();
            const stepMatch = line.match(/\(([0-9]+)\/([0-9]+)\)\s+(?:upgrading|installing|reinstalling)\s+(\S+)/);
            if (stepMatch) {
                const curr = parseInt(stepMatch[1]);
                const tot = parseInt(stepMatch[2]);
                if (tot > 0)
                    return Math.min(0.92, 0.15 + (curr / tot) * 0.75);
            }
            if (line.indexOf("Restarting hype.service") >= 0)
                return 0.95;
            if (line.indexOf("Building HypeShell") >= 0 || line.indexOf("make -C") >= 0)
                return 0.65;
            if (line.indexOf("Tidying Go modules") >= 0)
                return 0.45;
            if (line.indexOf("Cloning HypeShell") >= 0)
                return 0.20;
            if (line.indexOf("Retrieving packages") >= 0 || line.indexOf("downloading ") === 0)
                return 0.15;
            if (line.indexOf("Upgrade complete") >= 0)
                return 1.0;
        }
        return 0.08;
    }

    function _computeStepFromLog(lines) {
        if (!lines || lines.length === 0)
            return I18n.tr("Starting update…");
        for (let i = lines.length - 1; i >= 0; i--) {
            const line = String(lines[i]).trim();
            const stepMatch = line.match(/\(([0-9]+)\/([0-9]+)\)\s+(?:upgrading|installing|reinstalling)\s+(\S+)/);
            if (stepMatch) {
                return I18n.tr("Installing updates (%1 of %2)").arg(stepMatch[1]).arg(stepMatch[2]);
            }
            if (line.indexOf("Restarting hype.service") >= 0)
                return I18n.tr("Restarting shell service…");
            if (line.indexOf("Building HypeShell") >= 0 || line.indexOf("make -C") >= 0)
                return I18n.tr("Compiling HypeShell…");
            if (line.indexOf("Tidying Go modules") >= 0)
                return I18n.tr("Preparing dependencies…");
            if (line.indexOf("Cloning HypeShell") >= 0)
                return I18n.tr("Downloading HypeShell update…");
            if (line.indexOf("Retrieving packages") >= 0 || line.indexOf("downloading ") === 0)
                return I18n.tr("Downloading packages…");
            if (line.indexOf("Upgrade complete") >= 0)
                return I18n.tr("Update complete!");
        }
        return I18n.tr("Updating system…");
    }

    function checkForUpdates() {
        HYPEService.sysupdateRefresh(false, null);
    }

    function runUpdates(opts) {
        const params = opts || {};
        if (SettingsData.updaterUseCustomCommand && SettingsData.updaterCustomCommand.length > 0) {
            _runCustomTerminalCommand();
            return;
        }
        HYPEService.sysupdateUpgrade(params, null);
    }

    function cancelUpdates() {
        HYPEService.sysupdateCancel(null);
    }

    function setInterval(seconds) {
        HYPEService.sysupdateSetInterval(seconds, null);
    }

    function _runCustomTerminalCommand() {
        const terminal = SessionData.resolveTerminal();
        if (!terminal || terminal.length === 0) {
            ToastService.showError(I18n.tr("No terminal configured"), I18n.tr("Pick a terminal in Settings → Launcher (or set $TERMINAL)."));
            return;
        }
        const updateCommand = `${SettingsData.updaterCustomCommand}; status=$?; if [ "$status" -eq 0 ]; then echo "Updates complete. Closing…"; sleep 1; else echo "Update failed (exit $status). Press Enter to close."; read _; fi; exit "$status"`;
        const termClass = SettingsData.updaterTerminalAdditionalParams || "";
        var argv = [terminal];
        if (termClass.length > 0) {
            argv = argv.concat(termClass.split(" "));
        }
        argv.push("-e");
        argv.push("sh");
        argv.push("-c");
        argv.push(updateCommand);
        customRunner.command = argv;
        customRunner.running = true;
    }

    Process {
        id: customRunner
        onExited: root.checkForUpdates()
    }

    onRefCountChanged: _syncAcquire()
    onSysupdateAvailableChanged: _syncAcquire()

    property bool _acquired: false

    function _syncAcquire() {
        const want = refCount > 0 && sysupdateAvailable;
        if (want === _acquired) {
            return;
        }
        _acquired = want;
        if (want) {
            HYPEService.sysupdateAcquire(null);
            return;
        }
        HYPEService.sysupdateRelease(null);
    }

}
