import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "ioMonitor"

    StyledText {
        width: parent.width
        text: "I/O Monitor"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Live disk read and write throughput in your DankBar, updated every second. Works in both horizontal and vertical bars."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "Appearance"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "showIcon"
        label: "Show icon"
        description: "Display the disk icon in the pill"
        defaultValue: true
    }

    SelectionSetting {
        id: iconChoice
        settingKey: "iconChoice"
        label: "Icon"
        description: "Which symbol to show"
        defaultValue: "hard_disk"
        options: [
            { "label": "Hard disk", "value": "hard_disk" },
            { "label": "Hard drive", "value": "hard_drive" },
            { "label": "Platter", "value": "album" },
            { "label": "Storage", "value": "storage" },
            { "label": "Database", "value": "database" },
            { "label": "Save", "value": "save" },
            { "label": "Read/write arrows", "value": "swap_vert" },
            { "label": "Transfer arrows", "value": "sync_alt" },
            { "label": "Custom…", "value": "custom" }
        ]
    }

    StringSetting {
        visible: iconChoice.value === "custom"
        settingKey: "customIconName"
        label: "Custom icon name"
        description: "Any Material Symbols name, e.g. hard_drive_2. Falls back to hard_disk if the name is empty."
        placeholder: "hard_disk"
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "showLabel"
        label: "Show label"
        description: "Display a text label between the icon and the chart. Horizontal bars only — a vertical bar has no room for it"
        defaultValue: true
    }

    StringSetting {
        settingKey: "labelText"
        label: "Label text"
        description: "The label shown next to the icon"
        placeholder: "I/O"
        defaultValue: "I/O"
    }

    ToggleSetting {
        settingKey: "showValue"
        label: "Show percentage"
        description: "Display the numeric reading next to (or below) the chart"
        defaultValue: true
    }

    SelectionSetting {
        id: chartChoice
        settingKey: "chartStyle"
        label: "Chart style"
        description: "How the combined read and write throughput is drawn"
        defaultValue: "hbar"
        options: [
            { "label": "Horizontal bar", "value": "hbar" },
            { "label": "Vertical bar", "value": "bar" },
            { "label": "Gauge", "value": "gauge" },
            { "label": "Donut", "value": "donut" },
            { "label": "Pie", "value": "pie" },
            { "label": "None", "value": "none" }
        ]
    }

    ToggleSetting {
        visible: chartChoice.value === "gauge" || chartChoice.value === "donut" || chartChoice.value === "pie"
        settingKey: "iconInChart"
        label: "Icon inside chart"
        description: "Draw the icon in the middle of the chart instead of beside it. The chart grows to make room, up to the thickness of your bar"
        defaultValue: true
    }

    SliderSetting {
        visible: chartChoice.value === "hbar" || chartChoice.value === "bar"
        settingKey: "chartBarThickness"
        label: chartChoice.value === "bar" ? "Bar width" : "Bar height"
        description: "How thick the bar is drawn, as a share of the space it is given"
        defaultValue: 35
        minimum: 5
        maximum: 100
        unit: "%"
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "Measurement"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "fullScaleMb"
        label: "Throughput that counts as 100%"
        description: "Megabytes per second that fill the chart. Reads and writes count together"
        defaultValue: 200
        minimum: 10
        maximum: 2000
        unit: " MB/s"
    }

    SliderSetting {
        settingKey: "topCount"
        label: "Entries to show"
        description: "How many rows the popout lists, busiest first"
        defaultValue: 30
        minimum: 5
        maximum: 60
        unit: ""
    }
}
