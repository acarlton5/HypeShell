pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services
import qs.Modules.Plugins

Singleton {
    id: root

    enum Backend {
        None,
        KDEConnect,
        Valent
    }

    property int preferredBackend: PhoneConnectService.Backend.KDEConnect
    property int activeBackend: PhoneConnectService.Backend.None

    readonly property bool available: activeBackend !== PhoneConnectService.Backend.None
    readonly property bool initialized: available && (_backend?.initialized ?? false)
    readonly property bool isRefreshing: _backend?.isRefreshing ?? false
    readonly property bool supportsSms: _backend?.supportsSms ?? false

    readonly property string announcedName: _backend?.announcedName ?? ""
    readonly property string selfId: _backend?.selfId ?? ""

    readonly property var deviceIds: _backend?.deviceIds ?? []
    readonly property var devices: {
        const rawDevices = _backend?.devices ?? {};
        const result = {};
        for (const id in rawDevices) {
            const dev = rawDevices[id];
            if (dev) {
                const copy = Object.assign({}, dev);
                if (deviceTypeMap && deviceTypeMap[id]) {
                    copy.type = deviceTypeMap[id];
                }
                result[id] = copy;
            }
        }
        return result;
    }

    readonly property var connectedDevices: _backend?.connectedDevices ?? []
    readonly property var pairedDevices: _backend?.pairedDevices ?? []
    readonly property int connectedCount: _backend?.connectedCount ?? 0
    readonly property int pairedCount: _backend?.pairedCount ?? 0

    readonly property string backendName: {
        switch (activeBackend) {
        case PhoneConnectService.Backend.KDEConnect:
            return "KDE Connect";
        case PhoneConnectService.Backend.Valent:
            return "Valent";
        default:
            return "None";
        }
    }

    property var _backend: null
    property bool _nameWatchSubscribed: false
    property bool _activationAttempted: false

    signal devicesListChanged
    signal deviceUpdated(string deviceId)
    signal deviceAdded(string deviceId)
    signal deviceRemoved(string deviceId)
    signal pairingRequestReceived(string deviceId, string verificationKey)
    signal shareReceived(string deviceId, string url)
    signal backendChanged

    function subscribeToNameOwnerChanges() {
        if (_nameWatchSubscribed || !HYPEService.isConnected)
            return;
        _nameWatchSubscribed = true;
        HYPEService.dbusSubscribe("session", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameOwnerChanged", function(response) {
            if (response.error) {
                console.warn("[PhoneConnect] NameOwnerChanged subscription failed:", response.error);
                _nameWatchSubscribed = false;
            }
        });
    }

    function tryActivateBackend() {
        if (_activationAttempted || !HYPEService.isConnected)
            return;
        _activationAttempted = true;

        HYPEService.dbusCall("session", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "ListActivatableNames", [], function(response) {
            if (response.error)
                return;
            const activatable = response.result?.values?.[0] || [];
            const canKDE = activatable.includes("org.kde.kdeconnect");
            const canValent = activatable.includes("ca.andyholmes.Valent");

            let targetService = "";
            if (preferredBackend === PhoneConnectService.Backend.KDEConnect && canKDE) {
                targetService = "org.kde.kdeconnect";
            } else if (preferredBackend === PhoneConnectService.Backend.Valent && canValent) {
                targetService = "ca.andyholmes.Valent";
            } else if (canKDE) {
                targetService = "org.kde.kdeconnect";
            } else if (canValent) {
                targetService = "ca.andyholmes.Valent";
            }

            if (!targetService)
                return;

            HYPEService.dbusCall("session", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "StartServiceByName", [targetService, 0], function(startResp) {
                if (startResp.error) {
                    console.warn("[PhoneConnect] Failed to DBus-activate", targetService, ":", startResp.error);
                    return;
                }
                detectBackend();
            });
        });
    }

    Component.onCompleted: {
        detectBackend();
        subscribeToNameOwnerChanges();
        updateDeviceTypeMap();
    }

    Connections {
        target: HYPEService
        function onConnectionStateChanged() {
            if (!HYPEService.isConnected) {
                _nameWatchSubscribed = false;
                _activationAttempted = false;
                return;
            }
            subscribeToNameOwnerChanges();
            detectBackend();
        }

        function onDbusSignalReceived(subId, data) {
            if (data.member === "NameOwnerChanged") {
                const name = data.body?.[0] || "";
                if (name === "org.kde.kdeconnect" || name === "ca.andyholmes.Valent") {
                    detectBackend();
                }
            }
        }
    }

    Connections {
        target: KDEConnectService
        function onAvailableChanged() {
            if ((KDEConnectService.available && activeBackend === PhoneConnectService.Backend.None) ||
                (!KDEConnectService.available && activeBackend === PhoneConnectService.Backend.KDEConnect)) {
                detectBackend();
            }
        }
    }

    Connections {
        target: ValentService
        function onAvailableChanged() {
            if ((ValentService.available && activeBackend === PhoneConnectService.Backend.None) ||
                (!ValentService.available && activeBackend === PhoneConnectService.Backend.Valent)) {
                detectBackend();
            }
        }
    }

    Connections {
        target: KDEConnectService
        enabled: activeBackend === PhoneConnectService.Backend.KDEConnect

        function onDevicesListChanged() {
            root.devicesListChanged();
        }
        function onDeviceUpdated(deviceId) {
            root.deviceUpdated(deviceId);
        }
        function onDeviceAdded(deviceId) {
            root.deviceAdded(deviceId);
        }
        function onDeviceRemoved(deviceId) {
            root.deviceRemoved(deviceId);
        }
        function onPairingRequestReceived(deviceId, verificationKey) {
            root.pairingRequestReceived(deviceId, verificationKey);
        }
        function onShareReceived(deviceId, url) {
            root.shareReceived(deviceId, url);
        }
    }

    Connections {
        target: ValentService
        enabled: activeBackend === PhoneConnectService.Backend.Valent

        function onDevicesListChanged() {
            root.devicesListChanged();
        }
        function onDeviceUpdated(deviceId) {
            root.deviceUpdated(deviceId);
        }
        function onDeviceAdded(deviceId) {
            root.deviceAdded(deviceId);
        }
        function onDeviceRemoved(deviceId) {
            root.deviceRemoved(deviceId);
        }
        function onPairingRequestReceived(deviceId, verificationKey) {
            root.pairingRequestReceived(deviceId, verificationKey);
        }
        function onShareReceived(deviceId, url) {
            root.shareReceived(deviceId, url);
        }
    }

    function detectBackend() {
        if (!HYPEService.isConnected)
            return;

        HYPEService.dbusListNames("session", function(response) {
            if (response.error)
                return;

            const names = response.result?.names || [];
            const hasKDE = names.includes("org.kde.kdeconnect");
            const hasValent = names.includes("ca.andyholmes.Valent");

            let newBackend = PhoneConnectService.Backend.None;

            if (preferredBackend === PhoneConnectService.Backend.KDEConnect && hasKDE) {
                newBackend = PhoneConnectService.Backend.KDEConnect;
            } else if (preferredBackend === PhoneConnectService.Backend.Valent && hasValent) {
                newBackend = PhoneConnectService.Backend.Valent;
            } else if (hasKDE) {
                newBackend = PhoneConnectService.Backend.KDEConnect;
            } else if (hasValent) {
                newBackend = PhoneConnectService.Backend.Valent;
            }

            if (newBackend !== activeBackend) {
                activeBackend = newBackend;
                switch (activeBackend) {
                case PhoneConnectService.Backend.KDEConnect:
                    _backend = KDEConnectService;
                    if (!KDEConnectService.available)
                        KDEConnectService.checkAvailability();
                    break;
                case PhoneConnectService.Backend.Valent:
                    _backend = ValentService;
                    if (!ValentService.available)
                        ValentService.checkAvailability();
                    break;
                default:
                    _backend = null;
                }
                backendChanged();
                devicesListChanged();
            }

            if (newBackend === PhoneConnectService.Backend.None && !_activationAttempted) {
                tryActivateBackend();
            }
        });
    }

    function refreshDevices() {
        if (!_backend) {
            _activationAttempted = false;
            detectBackend();
            return;
        }
        _backend.refreshDevices();
    }

    function getDevice(deviceId) {
        return devices[deviceId] || null;
    }

    function hasPlugin(deviceId, pluginName) {
        const dev = getDevice(deviceId);
        if (!dev || !dev.supportedPlugins) return false;
        
        return dev.supportedPlugins.includes(pluginName) || 
               dev.supportedPlugins.includes("kdeconnect_" + pluginName);
    }

    function ringDevice(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.ringDevice(deviceId, callback);
    }

    function shareUrl(deviceId, url, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.shareUrl(deviceId, url, callback);
    }

    function shareText(deviceId, text, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.shareText(deviceId, text, callback);
    }

    function shareFile(deviceId, path, callback) {
        const url = localFileUrl(path);
        if (url === "") {
            callback?.({
                error: "Invalid file path"
            });
            return;
        }
        shareUrl(deviceId, url, callback);
    }

    function localFileUrl(path) {
        if (path === undefined || path === null)
            return "";
        const filePath = path.toString();
        if (filePath === "")
            return "";
        if (filePath.startsWith("file://"))
            return filePath;
        if (!filePath.startsWith("/"))
            return "";

        const encoded = filePath.split("/").map(function(segment) {
            return encodeURIComponent(segment);
        }).join("/");

        return "file://" + encoded;
    }

    function sendClipboard(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.sendClipboard(deviceId, callback);
    }

    function requestPairing(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.requestPairing(deviceId, callback);
    }

    function acceptPairing(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.acceptPairing(deviceId, callback);
    }

    function cancelPairing(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.cancelPairing(deviceId, callback);
    }

    function unpair(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.unpair(deviceId, callback);
    }

    function setLocked(deviceId, locked, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.setLocked(deviceId, locked, callback);
    }

    function getRemoteCommands(deviceId, callback) {
        if (!_backend) {
            callback?.([]);
            return;
        }
        _backend.getRemoteCommands(deviceId, callback);
    }

    function triggerRemoteCommand(deviceId, commandKey, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.triggerRemoteCommand(deviceId, commandKey, callback);
    }

    function getMprisPlayers(deviceId, callback) {
        if (!_backend) {
            callback?.([]);
            return;
        }
        _backend.getMprisPlayers(deviceId, callback);
    }

    function mprisAction(deviceId, action, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.mprisAction(deviceId, action, callback);
    }

    function sendPing(deviceId, message, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.sendPing(deviceId, message, callback);
    }

    function mountSftp(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.mountSftp(deviceId, callback);
    }

    function unmountSftp(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.unmountSftp(deviceId, callback);
    }

    function mountAndWait(deviceId, callback) {
        if (!_backend) {
            callback?.(false);
            return;
        }
        _backend.mountAndWait(deviceId, callback);
    }

    function startBrowsing(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.startBrowsing(deviceId, callback);
    }

    function browseDevice(deviceId, callback) {
        if (!_backend) {
            callback?.(false, "");
            return;
        }
        _backend.browseDevice(deviceId, callback);
    }

    function getSftpMountPoint(deviceId, callback) {
        if (!_backend) {
            callback?.("");
            return;
        }
        _backend.getSftpMountPoint(deviceId, callback);
    }

    function isSftpMounted(deviceId, callback) {
        if (!_backend) {
            callback?.(false);
            return;
        }
        _backend.isSftpMounted(deviceId, callback);
    }

    function requestPhoto(deviceId, savePath, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.requestPhoto(deviceId, savePath, callback);
    }

    function sendSms(deviceId, addresses, message, attachmentUrls, callback) {
        if (activeBackend === PhoneConnectService.Backend.KDEConnect) {
            const addr = Array.isArray(addresses) ? (addresses[0] || "") : (addresses || "");
            Quickshell.execDetached([
                "kdeconnect-cli",
                "-d",
                deviceId,
                "--send-sms",
                message,
                "--destination",
                addr
            ]);
            callback?.({ success: true });
            return;
        }

        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.sendSms(deviceId, addresses, message, attachmentUrls, callback);
    }

    function launchSmsApp(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.launchSmsApp(deviceId, callback);
    }

    function getConversations(deviceId, callback) {
        if (!_backend) {
            callback?.([]);
            return;
        }
        _backend.getConversations(deviceId, callback);
    }

    property var deviceTypeMap: ({})
    onDeviceTypeMapChanged: {
        root.devicesListChanged();
    }

    function updateDeviceTypeMap() {
        let changed = false;
        let newMap = {};
        if (PluginService.globalVars && PluginService.globalVars["hypeKDEConnect"]) {
            const vars = PluginService.globalVars["hypeKDEConnect"];
            if (vars && vars["deviceTypeMap"]) {
                try {
                    newMap = JSON.parse(vars["deviceTypeMap"]);
                    changed = true;
                } catch(e) {}
            }
        }
        if (!changed) {
            try {
                const data = SettingsData.pluginSettings["hypeKDEConnect"];
                if (data?.deviceTypeMap) {
                    newMap = JSON.parse(data.deviceTypeMap);
                    changed = true;
                }
            } catch(e) {}
        }
        
        if (JSON.stringify(deviceTypeMap) !== JSON.stringify(newMap)) {
            deviceTypeMap = newMap;
            root.devicesListChanged();
        }
    }

    Connections {
        target: PluginService
        ignoreUnknownSignals: true
        function onGlobalVarChanged(pluginId, varName) {
            if (pluginId === "hypeKDEConnect" && varName === "deviceTypeMap") {
                root.updateDeviceTypeMap();
            }
        }
        function onPluginDataChanged(pluginId) {
            if (pluginId === "hypeKDEConnect") {
                root.updateDeviceTypeMap();
            }
        }
    }

    function getDeviceIcon(device) {
        if (!device) return "smartphone";
        const deviceId = device.id;
        if (deviceId && deviceTypeMap[deviceId]) {
            switch (deviceTypeMap[deviceId]) {
            case "phone": return "smartphone";
            case "tablet": return "tablet";
            case "laptop": return "laptop";
            case "desktop": return "desktop_windows";
            case "tv": return "tv";
            }
        }
        let icon = _backend?.getDeviceIcon(device) ?? "smartphone";
        if (icon === "computer") icon = "desktop_windows";
        return icon;
    }

    function getNetworkIcon(device) {
        return _backend?.getNetworkIcon(device) ?? "";
    }

    function getBatteryIcon(device) {
        return _backend?.getBatteryIcon(device) ?? "";
    }

    function getNetworkTypeLabel(device) {
        if (!device || !device.networkType)
            return "N/A";
        
        const rawType = device.networkType.toString().trim();
        const type = rawType.toUpperCase();
        
        // Map common network types to friendly, standard representations
        switch (type) {
        case "NR":
        case "5G":
        case "5G_NR":
        case "5G NR":
            return "5G";
        case "LTE":
        case "4G":
            return "LTE";
        case "LTE_CA":
        case "LTE+":
        case "4G+":
        case "4G_CA":
            return "LTE+";
        case "HSPA":
        case "HSDPA":
        case "HSUPA":
        case "HSPAP":
        case "UMTS":
        case "WCDMA":
        case "3G":
            return "3G";
        case "EDGE":
        case "GPRS":
        case "GSM":
        case "2G":
            return "2G";
        default:
            // Format unknown types nicely (e.g. capitalize first letter)
            if (rawType.length > 0) {
                return rawType.charAt(0).toUpperCase() + rawType.slice(1);
            }
            return "N/A";
        }
    }

    function getNetworkStrengthLabel(device) {
        if (!device || device.networkStrength === undefined || device.networkStrength < 0)
            return "Unknown";
        const strength = device.networkStrength;
        if (strength >= 4) return "Excellent";
        if (strength === 3) return "Good";
        if (strength === 2) return "Fair";
        if (strength === 1) return "Weak";
        return "No Signal";
    }

    function getNetworkTypeIcon(device) {
        if (!device || !device.networkType)
            return "signal_cellular_nodata";
        const label = getNetworkTypeLabel(device);
        switch (label) {
        case "5G":
            return "5g";
        case "LTE":
        case "LTE+":
            return "4g_mobiledata";
        case "3G":
            return "3g_mobiledata";
        case "2G":
            return "2g_mobiledata";
        default:
            return "signal_cellular_alt";
        }
    }
}
