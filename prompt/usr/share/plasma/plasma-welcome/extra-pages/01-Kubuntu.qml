/*
 *  SPDX-FileCopyrightText: 2021 Felipe Kinoshita <kinofhek@gmail.com>
 *  SPDX-FileCopyrightText: 2022 Nate Graham <nate@kde.org>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Qt5Compat.GraphicalEffects

import org.kde.plasma.welcome

GenericPage {
    heading: i18nc("@info:window", "Welcome to Kubuntu | Friendly Computing")
    description: i18nc("@info:usagetip",
    '<p>You are using the Kubuntu® Linux distribution, an official Ubuntu® flavor.
      It is used by millions around the world who value:</p>

    <ul>
      <li>The beautiful and intuitive KDE Plasma desktop and KDE apps</li>
      <li>The breadth and compatibility of the full Ubuntu
      archive</li>
      <li>Frequent security updates</li>
      <li>Current, reliable core apps for productivity, office, email,
      graphics, and music</li>
      <li>The availability of Kubuntu-optimized hardware and commercial support</li>
    </ul>

    <p>Kubuntu is free software developed by members of the global Ubuntu®
    community. Please donate today to support its continued development. All
    proceeds fund the Kubuntu Developer Team!</p>
    ');

    RowLayout {
        Layout.fillWidth: true;
        anchors {
          left: parent.left
          right: parent.right
        }
        Image {
            id: features 
            source: "/usr/share/kubuntu-default-settings/kubuntu_tour.svg"
            mipmap : true
            Layout.topMargin       : 0 - Kirigami.Units.gridUnit 
            Layout.leftMargin      : Kirigami.Units.gridUnit * 3
            Layout.alignment       : Qt.AlignLeft + Qt.AlignVCenter
            Layout.preferredHeight : Kirigami.Units.gridUnit * 5
            Layout.preferredWidth  :
                ( this.implicitWidth / this.implicitHeight )
                * (Kirigami.Units.gridUnit * 5)

            HoverHandler {
                id: hoverhandler
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: Qt.openUrlExternally("https://kubuntu.org/feature-tour/")
            }
            QQC2.ToolTip {
                visible: hoverhandler.hovered
                text: i18nc("@action:button", "See what makes Kubuntu special.")
            }

            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 0
                verticalOffset: 0
                radius: 15
                samples: 20
                color: Qt.rgba(0, 0, 0, 0.2)
            }
        }
        Image {
            id: donate
            source: "/usr/share/kubuntu-default-settings/kubuntu_donate.svg"
            mipmap : true
            Layout.topMargin       : 0 - Kirigami.Units.gridUnit 
            Layout.rightMargin     : Kirigami.Units.gridUnit * 3
            Layout.alignment       : Qt.AlignRight - Qt.AlignVCenter
            Layout.preferredHeight : Kirigami.Units.gridUnit * 5
            Layout.preferredWidth  :
                ( this.implicitWidth / this.implicitHeight )
                * (Kirigami.Units.gridUnit * 5)

            HoverHandler {
                id: donate_hoverhandler
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: Qt.openUrlExternally("https://kubuntu.org/donate/")
            }
            QQC2.ToolTip {
                visible: donate_hoverhandler.hovered
                text: i18nc("@action:button",
                    "Help keep Kubuntu wonderful and free.")
            }

            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 0
                verticalOffset: 0
                radius: 15
                samples: 20
                color: Qt.rgba(0, 0, 0, 0.2)
            }
        }
    }
}
