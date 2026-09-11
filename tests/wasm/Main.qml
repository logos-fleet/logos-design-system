import QtQuick
import Logos.Theme
import Logos.Controls

Window {
    visible: true
    width: 360
    height: 240
    color: Theme.palette.background

    LogosFrame {
        anchors.centerIn: parent

        Column {
            spacing: Theme.spacing.large

            LogosText { text: "logos-ds-wasm-smoke" }
            LogosButton { text: "press" }
        }
    }
}
