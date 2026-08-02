import QtQuick
import qs.Common
import qs.Widgets

// One pill for both bar orientations. Horizontal lays the parts out in a row
// (icon, label, chart, value); vertical stacks them and drops the label, which
// never fits in a bar only as wide as one icon.
Item {
    id: root

    required property var pluginRoot
    property bool isVerticalOrientation: false

    // The DankBar carries its own thickness, font and icon scales; a pill that
    // ignores them stays put while everything else resizes.
    readonly property int iconSize: Theme.barIconSize(pluginRoot.barThickness, undefined, pluginRoot.barConfig?.maximizeWidgetIcons, pluginRoot.barConfig?.iconScale)
    readonly property int textSize: Theme.barTextSize(pluginRoot.barThickness, pluginRoot.barConfig?.fontScale, pluginRoot.barConfig?.maximizeWidgetText)

    readonly property string chartStyle: pluginRoot.chartStyle
    readonly property bool showChart: chartStyle !== "none"
    readonly property bool showIcon: pluginRoot.showIcon
    readonly property bool showValue: pluginRoot.showValue
    readonly property bool showLabel: pluginRoot.showLabel && !isVerticalOrientation

    readonly property bool chartIsRound: chartStyle === "gauge" || chartStyle === "donut" || chartStyle === "pie"
    readonly property bool iconInChart: showIcon && showChart && chartIsRound && pluginRoot.iconInChart

    // A round chart holding an icon has to grow, because the icon only gets the
    // hole in the middle: a chart sized for a bar would leave a few unreadable
    // pixels. The bar's own thickness is the ceiling — past that the pill would
    // spill out of the widget and into the bar around it.
    readonly property real baseChartSize: Math.max(iconSize + 4, Math.round(textSize * 1.75))
    readonly property real roundChartSize: Math.min(Math.max(14, pluginRoot.widgetThickness - 2), Math.round(iconSize / (chartStyle === "pie" ? 0.52 : 0.44)))
    readonly property real chartSize: iconInChart ? Math.max(baseChartSize, roundChartSize) : baseChartSize

    readonly property real percent: Math.min(pluginRoot.combinedPercent, 999)
    readonly property color accent: pluginRoot.usageColor(pluginRoot.combinedPercent)

    // Reserve exactly the width of the widest value so the pill never resizes as
    // digits change, without parking short values far from the rest of the row.
    TextMetrics {
        id: valueMetrics
        font.pixelSize: root.textSize
        text: "100%"
    }

    // Shared column width in the vertical bar so the icon, chart and value all
    // center on the same axis. Derived from font/icon metrics rather than from
    // the Column (which would be a binding loop and collapse the pill).
    readonly property real columnWidth: Math.max(showIcon && !iconInChart ? iconSize : 0, showChart ? chartSize : 0, showValue ? valueMetrics.width : 0)

    // The linear charts want to run along the bar; the round ones stay square.
    readonly property real chartW: isVerticalOrientation ? (chartStyle === "hbar" ? columnWidth : chartSize) : (chartStyle === "hbar" ? Math.round(textSize * 3.7) : chartSize)
    readonly property real chartH: isVerticalOrientation ? (chartStyle === "bar" ? Math.round(chartSize * 1.6) : chartSize) : chartSize

    implicitWidth: isVerticalOrientation ? verticalLayout.implicitWidth : horizontalLayout.implicitWidth
    implicitHeight: isVerticalOrientation ? verticalLayout.implicitHeight : horizontalLayout.implicitHeight

    Row {
        id: horizontalLayout
        visible: !root.isVerticalOrientation
        spacing: Theme.spacingS

        DankIcon {
            visible: root.showIcon && !root.iconInChart
            name: root.pluginRoot.iconName
            size: root.iconSize
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            visible: root.showLabel
            text: root.pluginRoot.labelText
            font.pixelSize: root.textSize
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            spacing: 4
            visible: root.showChart || root.showValue
            anchors.verticalCenter: parent.verticalCenter

            IoChart {
                visible: root.showChart
                width: root.showChart ? root.chartW : 0
                height: root.chartH
                chartType: root.chartStyle
                progress: root.percent / 100
                fillColor: root.accent
                barThickness: root.pluginRoot.chartBarThickness
                labelIcon: root.iconInChart ? root.pluginRoot.iconName : ""
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.showValue
                width: valueMetrics.width
                horizontalAlignment: Text.AlignLeft
                text: `${root.percent.toFixed(0)}%`
                font.pixelSize: root.textSize
                color: Theme.surfaceText
                wrapMode: Text.NoWrap
                maximumLineCount: 1
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Column {
        id: verticalLayout
        visible: root.isVerticalOrientation
        spacing: 2

        DankIcon {
            visible: root.showIcon && !root.iconInChart
            anchors.horizontalCenter: parent.horizontalCenter
            name: root.pluginRoot.iconName
            size: root.iconSize
            color: Theme.surfaceText
        }

        IoChart {
            visible: root.showChart
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.chartW
            height: root.showChart ? root.chartH : 0
            chartType: root.chartStyle
            progress: root.percent / 100
            fillColor: root.accent
            barThickness: root.pluginRoot.chartBarThickness
            labelIcon: root.iconInChart ? root.pluginRoot.iconName : ""
        }

        StyledText {
            visible: root.showValue
            anchors.horizontalCenter: parent.horizontalCenter
            width: valueMetrics.width
            horizontalAlignment: Text.AlignHCenter
            text: `${root.percent.toFixed(0)}%`
            font.pixelSize: root.textSize
            color: Theme.surfaceText
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }
}
