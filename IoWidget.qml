import QtQuick
import Quickshell
import Quickshell.Io

import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property real readRate: 0
    property real writeRate: 0
    property real prevIn: 0
    property real prevOut: 0
    property bool showIcon: pluginData.showIcon !== false
    property bool iconInChart: pluginData.iconInChart !== false
    property bool showLabel: pluginData.showLabel !== false
    property bool showValue: pluginData.showValue !== false
    property string labelText: pluginData.labelText || "I/O"
    property string chartStyle: pluginData.chartStyle || "hbar"
    property int fullScaleMb: pluginData.fullScaleMb || 200
    property int topCount: pluginData.topCount || 30
    property var rows: []
    property bool popoutOpen: false

    // A blank custom name means "not filled in yet", not "no icon" — that is what
    // the separate Show icon toggle is for.
    readonly property string iconName: {
        const choice = String(pluginData.iconChoice || "hard_disk")
        if (choice !== "custom") return choice
        const custom = String(pluginData.customIconName || "").trim()
        return custom.length > 0 ? custom : "hard_disk"
    }
    readonly property real chartBarThickness: Math.max(0.05, Math.min(1, Number(pluginData.chartBarThickness || 35) / 100))

    readonly property real combinedPercent: 100 * (readRate + writeRate) / (fullScaleMb * 1048576)

    function usageColor(percent) {
        if (percent > 90) return Theme.error
        if (percent > 75) return "#ffa500"
        return Theme.primary
    }

    function fmtRate(bytes) {
        if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + "G"
        if (bytes >= 1048576) {
            const m = bytes / 1048576
            return (m < 10 ? m.toFixed(1) : Math.round(m)) + "M"
        }
        if (bytes >= 1024) return Math.round(bytes / 1024) + "K"
        return "0"
    }

    Timer {
        // A hidden bar has nothing to show, so stop sampling until it comes back.
        // The counters are cleared on the way out so the first sample after a long
        // pause seeds a new baseline instead of reporting the whole gap as a spike.
        interval: 1000
        running: root._barRevealed
        repeat: true
        triggeredOnStart: true
        onTriggered: pillProcess.running = true
        onRunningChanged: {
            if (running) return
            root.prevIn = 0
            root.prevOut = 0
            root.readRate = 0
            root.writeRate = 0
        }
    }

    Process {
        id: pillProcess
        // /proc/vmstat counts block I/O in the VM layer, so it reports real
        // traffic even where per-device accounting is switched off.
        command: ["cat", "/proc/vmstat"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const gi = text.match(/^pgpgin (\d+)$/m)
                const go = text.match(/^pgpgout (\d+)$/m)
                if (!gi || !go) return
                const rd = parseInt(gi[1]) * 1024
                const wr = parseInt(go[1]) * 1024
                if (root.prevIn > 0) {
                    root.readRate = Math.max(0, rd - root.prevIn)
                    root.writeRate = Math.max(0, wr - root.prevOut)
                }
                root.prevIn = rd
                root.prevOut = wr
            }
        }
    }

    // Warm the list in the background: the collectors take up to a second, and
    // starting them on click leaves the popout empty until they finish.
    Timer {
        interval: root.popoutOpen ? 2000 : 20000
        running: root._barRevealed || root.popoutOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: rowsProcess.running = true
    }

    onPopoutOpenChanged: if (popoutOpen) rowsProcess.running = true

    Process {
        id: rowsProcess
        command: ["sh", Qt.resolvedUrl("collect.sh").toString().replace("file://", ""), String(root.fullScaleMb)]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.trim().split("\n")) {
                    const f = line.split("\t")
                    if (f.length < 4) continue
                    if (f[0] === "T") continue
                    out.push({
                        value: parseInt(f[1]),
                        pid: f[2],
                        name: f[3],
                        detail: f[4] || "",
                        display: f[6] || "",
                        killable: f[0] === "P",
                        free: f[0] === "F",
                        pinned: f[0] === "F"
                    })
                }
                // Pinned rows keep their emitted order (Read, Write, Busiest).
                out.sort((a, b) => (a.pinned !== b.pinned) ? (a.pinned ? -1 : 1) : (a.pinned ? 0 : b.value - a.value))
                root.rows = out.slice(0, root.topCount)
            }
        }
    }

    Process {
        id: killProcess
        running: false
        onExited: rowsProcess.running = true
    }

    function killPid(pid) {
        killProcess.command = ["kill", pid]
        killProcess.running = true
    }

    horizontalBarPill: Component {
        IoPill {
            pluginRoot: root
            isVerticalOrientation: false
        }
    }

    verticalBarPill: Component {
        IoPill {
            pluginRoot: root
            isVerticalOrientation: true
        }
    }

    popoutWidth: 360

    popoutContent: Component {
        PopoutComponent {
            id: popout

            Binding {
                target: root
                property: "popoutOpen"
                value: popout.parentPopout ? popout.parentPopout.shouldBeVisible : false
            }

            Item {
                width: parent.width
                implicitHeight: rows.implicitHeight + Theme.spacingM * 2

                Column {
                    id: rows
                    x: Theme.spacingM
                    y: Theme.spacingM
                    width: parent.width - Theme.spacingM * 2
                    spacing: Theme.spacingXS

                    Repeater {
                        model: root.rows

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width - stats.width - 16 - Theme.spacingS * 2
                                spacing: 5
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    id: rowName
                                    width: Math.min(implicitWidth, parent.width)
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: modelData.free ? Theme.primary : (modelData.killable ? Theme.surfaceText : Theme.surfaceVariantText)
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    width: parent.width - rowName.width - parent.spacing
                                    visible: modelData.detail.length > 0
                                    text: modelData.detail
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceVariantText
                                    opacity: 0.55
                                    wrapMode: Text.NoWrap
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Row {
                                id: stats
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    width: 62
                                    horizontalAlignment: Text.AlignRight
                                    text: modelData.display
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: modelData.free ? Theme.primary : Theme.surfaceVariantText
                                    opacity: modelData.free ? 1.0 : 0.7
                                    wrapMode: Text.NoWrap
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    width: 40
                                    height: 4
                                    radius: 2
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.25)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: parent.width * Math.min(modelData.value / 100, 1)
                                        height: parent.height
                                        radius: parent.radius
                                        color: root.usageColor(modelData.value)
                                    }
                                }
                            }

                            Item {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    anchors.fill: parent
                                    visible: modelData.killable
                                    name: "close"
                                    size: 16
                                    color: killArea.containsMouse ? Theme.error : Theme.surfaceVariantText

                                    MouseArea {
                                        id: killArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.killPid(modelData.pid)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
