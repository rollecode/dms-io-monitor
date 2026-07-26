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
        text: "Live disk read and write throughput in your DankBar, updated every second."
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

    ToggleSetting {
        settingKey: "showLabel"
        label: "Show label"
        description: "Display a text label between the icon and the bar"
        defaultValue: true
    }

    StringSetting {
        settingKey: "labelText"
        label: "Label text"
        description: "The label shown next to the icon"
        placeholder: "I/O"
        defaultValue: "I/O"
    }

    SliderSetting {
        settingKey: "fullScaleMb"
        label: "Throughput that counts as 100%"
        description: "Megabytes per second that fill the bar. Reads and writes count together"
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
