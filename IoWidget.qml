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
    property var prevDisks: ({})
    property bool showLabel: pluginData.showLabel !== false
    property string labelText: pluginData.labelText || "I/O"
    property int fullScaleMb: pluginData.fullScaleMb || 200
    property int topCount: pluginData.topCount || 30
    property var rows: []
    property bool popoutOpen: false

    readonly property real combinedPercent: 100 * (readRate + writeRate) / (fullScaleMb * 1048576)

    // Bar-aware sizing: the DankBar carries its own font scale and thickness,
    // and a pill that ignores them stays put while everything else resizes.
    readonly property real pillFont: Theme.barTextSize(barThickness, barConfig ? barConfig.fontScale : undefined, barConfig ? barConfig.maximizeWidgetText : undefined)

    function usageColor(percent) {
        if (percent > 90) return Theme.error
        if (percent > 75) return "#ffa500"
        return Theme.primary
    }

    // Reserve exactly the width of the widest value so the pill never resizes
    // as digits change, without parking short values far from the bar.
    TextMetrics {
        id: pctMetrics
        font.pixelSize: root.pillFont
        text: "100%"
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
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pillProcess.running = true
    }

    Process {
        id: pillProcess
        command: ["cat", "/proc/diskstats"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let r = 0, w = 0
                const now = {}
                for (const line of text.split("\n")) {
                    const f = line.trim().split(/\s+/)
                    if (f.length < 10) continue
                    // Whole disks only: partitions would double-count.
                    if (!/^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|hd[a-z]+|mmcblk\d+)$/.test(f[2])) continue
                    const rd = parseInt(f[5]) * 512
                    const wr = parseInt(f[9]) * 512
                    now[f[2]] = [rd, wr]
                    const prev = root.prevDisks[f[2]]
                    if (prev) {
                        r += Math.max(0, rd - prev[0])
                        w += Math.max(0, wr - prev[1])
                    }
                }
                if (Object.keys(root.prevDisks).length > 0) {
                    root.readRate = r
                    root.writeRate = w
                }
                root.prevDisks = now
            }
        }
    }

    Timer {
        interval: 2000
        running: root.popoutOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: rowsProcess.running = true
    }

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
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: "swap_vert"
                size: root.iconSizeLarge
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.showLabel
                text: root.labelText
                font.pixelSize: root.pillFont
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: Math.round(root.pillFont * 3.7)
                    height: Math.max(4, Math.round(root.pillFont / 2))
                    radius: height / 2
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.25)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: parent.width * Math.min(root.combinedPercent, 100) / 100
                        height: parent.height
                        radius: parent.radius
                        color: root.usageColor(root.combinedPercent)
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                }

                StyledText {
                    width: pctMetrics.width
                    horizontalAlignment: Text.AlignLeft
                    text: `${Math.min(root.combinedPercent, 999).toFixed(0)}%`
                    font.pixelSize: root.pillFont
                    color: Theme.surfaceText
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
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
