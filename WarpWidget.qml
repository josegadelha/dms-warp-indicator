import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins
import qs.DCommon.Widgets

PluginComponent {
    id: root

    property bool isConnected: false
    property bool isConnecting: false
    property bool isLoading: false
    property bool toggling: false
    property string statusText: "Checking..."
    readonly property real barPillPadding: Theme.snap(
        (barConfig?.widgetPadding ?? SettingsData.barWidgetPaddingDefault)
            * (widgetThickness / 30),
        parentScreen ? CompositorService.getScreenScale(parentScreen) : 1
    )

    function updateStatus() {
        Proc.runCommand(
            "warpIndicator.status",
            ["warp-cli", "status"],
            (output, exitCode) => {
                if (exitCode === 0) {
                    const lowerOutput = output.toLowerCase()

                    if (lowerOutput.includes("connecting")) {
                        isConnected = false
                        isConnecting = true
                        statusText = "Connecting..."
                    } else if (lowerOutput.includes("disconnected")) {
                        isConnected = false
                        isConnecting = false
                        statusText = "Disconnected"
                    } else if (lowerOutput.includes("connected")) {
                        isConnected = true
                        isConnecting = false
                        statusText = "Connected"
                    } else {
                        isConnected = false
                        isConnecting = false
                        statusText = "Unknown"
                    }
                } else {
                    isConnected = false
                    isConnecting = false
                    statusText = "Error"
                }

                isLoading = isConnecting
            },
            100
        )
    }

    function toggleWarp() {
        if (isLoading)
            return

        const targetState = !isConnected
        const command = isConnected
            ? ["warp-cli", "disconnect"]
            : ["warp-cli", "connect"]

        isLoading = true
        toggling = true
        isConnected = targetState
        statusText = targetState ? "Connecting..." : "Disconnecting..."

        Proc.runCommand(
            "warpIndicator.toggle",
            command,
            (output, exitCode) => {
                if (exitCode === 0) {
                    if (typeof ToastService !== "undefined") {
                        ToastService.showInfo(
                            targetState
                                ? "Connecting WARP..."
                                : "Disconnecting WARP..."
                        )
                    }
                    afterToggleTimer.restart()
                } else {
                    if (typeof ToastService !== "undefined") {
                        ToastService.showError("WARP toggle failed")
                    }
                    toggling = false
                    isLoading = false
                    updateStatus()
                }
            },
            50
        )
    }

    Component.onCompleted: updateStatus()

    Timer {
        id: afterToggleTimer
        interval: 1500
        onTriggered: {
            root.toggling = false
            root.updateStatus()
        }
    }

    Timer {
        interval: root.isConnecting ? 1000 : 5000
        running: true
        repeat: true
        onTriggered: {
            if (!root.toggling)
                root.updateStatus()
        }
    }

    // Horizontal bar (top/bottom)
    horizontalBarPill: Component {
        Item {
            implicitWidth: Math.max(0, root.widgetThickness - root.barPillPadding * 2)
            implicitHeight: root.widgetThickness
            width: implicitWidth
            height: implicitHeight

            DIcon {
                anchors.centerIn: parent
                name: root.isConnected ? "vpn_lock" : "vpn_key_off"
                size: Theme.barIconSize(parent.height, -4)
                color: root.isConnected
                    ? Theme.primary
                    : Theme.widgetIconColor
                opacity: root.isLoading ? 0.5 : 1.0
            }

            DankTooltip {
                text: "WARP VPN\nClick to open"
            }
        }
    }

    // Vertical bar (left/right)
    verticalBarPill: Component {
        Item {
            implicitWidth: root.widgetThickness
            implicitHeight: Math.max(0, root.widgetThickness - root.barPillPadding * 2)
            width: implicitWidth
            height: implicitHeight

            DIcon {
                anchors.centerIn: parent
                name: root.isConnected ? "vpn_lock" : "vpn_key_off"
                size: Theme.barIconSize(parent.height, -4)
                color: root.isConnected
                    ? Theme.primary
                    : Theme.widgetIconColor
                opacity: root.isLoading ? 0.5 : 1.0
            }

            DankTooltip {
                text: "WARP VPN\nClick to open"
            }
        }
    }

    // Popout window
    popoutContent: Component {
        PopoutComponent {
            headerText: "Cloudflare WARP"
            detailsText: "VPN Connection Status"
            showCloseButton: true

            // Check status when popout opens
            Component.onCompleted: root.updateStatus()

            Column {
                width: parent.width
                spacing: Theme.spacingL

                // Status Display
                StyledRect {
                    width: parent.width
                    height: 100
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        DIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: root.isLoading
                                ? "vpn_key"
                                : (root.isConnected ? "vpn_lock" : "vpn_key_off")
                            size: 32
                            color: root.isConnected
                                ? Theme.primary
                                : Theme.widgetIconColor
                            opacity: root.isLoading ? 0.5 : 1.0
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.statusText
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                            color: root.isConnected
                                ? Theme.primary
                                : Theme.surfaceText
                        }
                    }
                }

                // Toggle Button
                DankButton {
                    width: parent.width
                    height: 48
                    text: root.isLoading
                        ? "Please wait..."
                        : (root.isConnected ? "Disconnect" : "Connect")
                    enabled: !root.isLoading

                    onClicked: root.toggleWarp()
                }

                // Info Text
                StyledText {
                    width: parent.width
                    text: root.isConnected
                        ? "Your connection is secured through Cloudflare WARP"
                        : "Click Connect to secure your connection"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    popoutWidth: 350
    popoutHeight: 300
}
