// HardPoint OS installer slideshow
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Timer {
        interval: 12000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    component HPSlide: Slide {
        property string heading
        property string body
        Rectangle {
            anchors.fill: parent
            color: "#0A0E17"
            Image {
                id: mark
                source: "logo.png"
                width: 96; height: 96
                fillMode: Image.PreserveAspectFit
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.14
            }
            Text {
                id: title
                text: heading
                color: "#03F4D4"
                font.pixelSize: 30
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: mark.bottom
                anchors.topMargin: 28
            }
            Text {
                text: body
                color: "#ECF0F7"
                font.pixelSize: 17
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width * 0.7
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: title.bottom
                anchors.topMargin: 18
            }
        }
    }

    HPSlide {
        heading: "Welcome to HardPoint OS"
        body: "A fast, secure desktop by HardPoint Networks that works the way Windows 11 does: Start menu and taskbar in the middle, quick settings and notifications on the right."
    }
    HPSlide {
        heading: "Work and school accounts"
        body: "Sign in with your Microsoft Entra ID account and enrol in Intune with Company Portal. Open HardPoint Accounts after installing."
    }
    HPSlide {
        heading: "Updates you control"
        body: "HardPoint Updates checks system, app and firmware updates in one place and takes a snapshot before every update, so you can always go back."
    }
    HPSlide {
        heading: "Ready for work and play"
        body: "Developer and IT tools, Microsoft Edge, Steam and Xbox Cloud Gaming. Pick extra apps in HardPoint Setup the first time you sign in."
    }
    HPSlide {
        heading: "Familiar shortcuts"
        body: "Win opens Start, Win+E Files, Win+L locks, Win+V clipboard history, Win+Shift+S screenshot, Ctrl+Shift+Esc System Monitor, Win+I Settings."
    }
}
