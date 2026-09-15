import QtQuick
import QtQuick.Controls

import Logos.Theme
import Logos.Controls

Control {
    id: root

    // --- Public API ---
    property alias text: input.text
    property string placeholderText: ""
    property color placeholderTextColor: Theme.palette.textTertiary
    property int echoMode: TextInput.Normal
    property alias validator: input.validator
    property alias readOnly: input.readOnly

    /** Expose the inner TextInput for advanced use (cursorPosition, select, etc.) */
    readonly property alias textInput: input

    // Exposed for inspection (e.g., from tests). Read-only.
    readonly property alias placeholderItem: placeholder
    readonly property alias backgroundItem: bg

    implicitWidth: 200
    implicitHeight: 40
    leftPadding: 12
    rightPadding: 12
    clip: true

    focusPolicy: Qt.StrongFocus
    activeFocusOnTab: true
    // Focus handed to the field (forceActiveFocus, tab, key navigation) lands on
    // the wrapper control; the editor is where it must end up.
    onActiveFocusChanged: if (activeFocus)
        input.forceActiveFocus()

    background: Rectangle {
        id: bg
        radius: Theme.spacing.radiusSmall
        color: Theme.palette.backgroundSecondary
        border.width: 1
        border.color: {
            if (input.validator && input.text.length > 0 && !input.acceptableInput)
                return Theme.palette.error
            if (input.activeFocus)
                return Theme.palette.overlayOrange
            return Theme.palette.backgroundElevated
        }
    }

    contentItem: Item {
        id: contentRow
        property alias input: input
        clip: true

        LogosText {
            id: placeholder
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: root.placeholderText
            color: root.placeholderTextColor
            font.pixelSize: Theme.typography.secondaryText
            visible: input.text.length === 0
        }

        TextInput {
            id: input
            clip: true
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Theme.typography.secondaryText
            color: input.validator && input.text.length > 0 && !input.acceptableInput ? Theme.palette.error : Theme.palette.text
            echoMode: root.echoMode
            enabled: root.enabled
            activeFocusOnTab: true

            // WHAT THIS FIELD IS CALLED, to anything that is not looking at it.
            //
            // A bare TextInput goes into the accessibility tree with an EMPTY
            // name: the words a sighted user identifies a Logos field by are
            // the PLACEHOLDER, and a placeholder is decoration as far as
            // accessibility is concerned. So a screen reader reads "text field"
            // and an automated driver has nothing to ask for -- on a phone,
            // where a `web` variant's UI is pixels in a canvas and the
            // accessibility tree is the only handle on it at all, that is the
            // difference between a form that can be driven and one that cannot
            // (logos-workspace#174).
            //
            // NAMED HERE RATHER THAN BY EACH CALLER, and the placeholder rather
            // than a new property, for the same reason: every field in the
            // system already has one, it already says what the field is for,
            // and a name a caller has to remember to set is a name most fields
            // will not have. `Accessible.name` attached to the CONTROL does not
            // reach this editor -- measured on Qt for WebAssembly, where the
            // wrapper is not in the tree at all -- so this is the only place it
            // can be said.
            Accessible.name: root.placeholderText
        }
    }
}
