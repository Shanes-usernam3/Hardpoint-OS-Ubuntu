// HardPoint OS sign-in splash
import QtQuick

Rectangle {
    id: root
    color: "#0A0E17"
    property int stage

    onStageChanged: {
        if (stage == 2) intro.running = true
    }

    Image {
        id: logo
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(root.height * 0.04)
        source: "images/logo.png"
        width: Math.round(Math.min(root.width, root.height) * 0.16)
        height: width
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        opacity: 0.0
        OpacityAnimator on opacity { id: intro; from: 0; to: 1; duration: 600; easing.type: Easing.InOutQuad; running: false }
    }

    Rectangle {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logo.bottom
        anchors.topMargin: Math.round(root.height * 0.06)
        width: Math.round(root.width * 0.12)
        height: 4
        radius: 2
        color: "#1A1B39"
        Rectangle {
            radius: 2
            height: parent.height
            width: parent.width * Math.min(1, root.stage / 6)
            color: "#03F4D4"
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
        }
    }
}
