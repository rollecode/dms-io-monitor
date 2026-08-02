import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets

// Reusable 0..1 progress chart: hbar | bar | gauge | donut | pie.
// Cheap Rectangles for the linear types and GPU-accelerated QtQuick.Shapes for
// the round ones — no Canvas, so nothing rasterizes on the CPU every second.
Item {
    id: root

    property string chartType: "hbar"
    property real progress: 0            // 0..1
    property color fillColor: Theme.primary
    property color trackColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.25)
    property real barThickness: 0.35     // 0..1 cross-axis thickness for bar / hbar
    property string labelIcon: ""        // Material Symbol drawn in the middle of a round chart

    // gauge and donut leave a hole to drop the icon into; the pie has none, so
    // the icon lands on the drawn face and is treated differently below. The
    // linear types have nowhere to put one at all.
    readonly property bool labelHollow: chartType === "gauge" || chartType === "donut"
    readonly property bool hasLabel: labelIcon.length > 0 && (labelHollow || chartType === "pie")
    // Thin the ring when an icon has to fit inside it — the hole is what is left
    // over after two ring widths, so every pixel shaved off it counts double.
    property real lineWidth: Math.max(2, Math.round(Math.min(width, height) * (hasLabel ? 0.11 : 0.14)))
    readonly property real labelSize: Math.round(Math.min(width, height) * (labelHollow ? 0.44 : 0.48))

    // The animation lives here rather than on each shape so every chart type
    // eases the same way, including the arc sweeps that can't animate a binding.
    readonly property real target: Math.max(0, Math.min(1, progress))
    property real p: target
    Behavior on p {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }
    Behavior on fillColor {
        ColorAnimation { duration: 400 }
    }

    // In the hollow centre of a gauge or donut the icon can carry the accent, the
    // way the ring does. The pie has no hole: mid-sweep the icon straddles fill
    // and track, and no single colour reads on both — so it gets a disc of the
    // surface colour to sit on, which is one background at every fill level.
    readonly property color labelColor: labelHollow ? fillColor : Theme.surfaceText

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (root.chartType) {
            case "bar": return barComp
            case "gauge": return gaugeComp
            case "donut": return donutComp
            case "pie": return pieComp
            default: return hbarComp
            }
        }
    }

    // Declared after the Loader so they paint over the chart they label. Left
    // slightly translucent so the wedge boundary still shows through and the
    // disc reads as part of the chart rather than a hole punched in it.
    Rectangle {
        visible: root.hasLabel && !root.labelHollow
        anchors.centerIn: parent
        width: Math.round(root.labelSize * 1.16)
        height: width
        radius: width / 2
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.62)
    }

    DankIcon {
        visible: root.hasLabel
        anchors.centerIn: parent
        name: root.labelIcon
        size: root.labelSize
        color: root.labelColor
    }

    // ---- HORIZONTAL BAR: bar of barThickness height, fills from the left ----
    Component {
        id: hbarComp
        Item {
            anchors.fill: parent
            readonly property real barH: Math.max(4, Math.round(height * root.barThickness))

            Rectangle {
                width: parent.width
                height: parent.barH
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.trackColor

                Rectangle {
                    width: Math.max(root.p > 0 ? parent.height : 0, parent.width * root.p)
                    height: parent.height
                    radius: parent.radius
                    color: root.fillColor
                }
            }
        }
    }

    // ---- VERTICAL BAR: column of barThickness width, fills from the bottom --
    Component {
        id: barComp
        Item {
            anchors.fill: parent
            readonly property real colW: Math.max(4, Math.round(width * root.barThickness))

            Rectangle {
                width: parent.colW
                height: parent.height
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.trackColor

                Rectangle {
                    width: parent.width
                    height: Math.max(root.p > 0 ? parent.width : 0, parent.height * root.p)
                    radius: parent.radius
                    anchors.bottom: parent.bottom
                    color: root.fillColor
                }
            }
        }
    }

    // ---- GAUGE: 270° arc with a gap at the bottom --------------------------
    Component {
        id: gaugeComp
        Shape {
            id: g
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            readonly property real cx: width / 2
            readonly property real cy: height / 2
            readonly property real r: Math.max(1, Math.min(width, height) / 2 - root.lineWidth)

            ShapePath {
                strokeColor: root.trackColor
                strokeWidth: root.lineWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: g.cx; centerY: g.cy; radiusX: g.r; radiusY: g.r; startAngle: 135; sweepAngle: 270 }
            }
            ShapePath {
                strokeColor: root.fillColor
                strokeWidth: root.lineWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: g.cx; centerY: g.cy; radiusX: g.r; radiusY: g.r; startAngle: 135; sweepAngle: 270 * root.p }
            }
        }
    }

    // ---- DONUT: full ring --------------------------------------------------
    Component {
        id: donutComp
        Shape {
            id: d
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            readonly property real cx: width / 2
            readonly property real cy: height / 2
            readonly property real r: Math.max(1, Math.min(width, height) / 2 - root.lineWidth)

            ShapePath {
                strokeColor: root.trackColor
                strokeWidth: root.lineWidth
                fillColor: "transparent"
                PathAngleArc { centerX: d.cx; centerY: d.cy; radiusX: d.r; radiusY: d.r; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: root.fillColor
                strokeWidth: root.lineWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: d.cx; centerY: d.cy; radiusX: d.r; radiusY: d.r; startAngle: -90; sweepAngle: 360 * root.p }
            }
        }
    }

    // ---- PIE: filled sector ------------------------------------------------
    Component {
        id: pieComp
        Shape {
            id: pie
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            readonly property real cx: width / 2
            readonly property real cy: height / 2
            readonly property real r: Math.max(1, Math.min(width, height) / 2 - 1)

            ShapePath {
                fillColor: root.trackColor
                strokeColor: "transparent"
                strokeWidth: 0
                PathAngleArc { centerX: pie.cx; centerY: pie.cy; radiusX: pie.r; radiusY: pie.r; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                fillColor: root.fillColor
                strokeColor: "transparent"
                strokeWidth: 0
                startX: pie.cx
                startY: pie.cy
                PathAngleArc { centerX: pie.cx; centerY: pie.cy; radiusX: pie.r; radiusY: pie.r; startAngle: -90; sweepAngle: 360 * root.p; moveToStart: false }
                PathLine { x: pie.cx; y: pie.cy }
            }
        }
    }
}
