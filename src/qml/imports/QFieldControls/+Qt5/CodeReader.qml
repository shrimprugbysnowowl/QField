import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Shapes 1.14
import QtMultimedia 5.14
import Qt.labs.settings 1.0

import org.qfield 1.0

import Theme 1.0

Popup {
  id : codeReader

  signal decoded(var string)

  property string decodedString: ''
  property var barcodeRequestedItem: undefined //<! when a feature form is requesting a bardcode, this will be set to attribute editor widget which triggered the request
  property int popupWidth: mainWindow.width <= mainWindow.height ? mainWindow.width - Theme.popupScreenEdgeMargin : mainWindow.height - Theme.popupScreenEdgeMargin
  property bool openedOnce: false

  width: popupWidth
  height: Math.min(mainWindow.height - Theme.popupScreenEdgeMargin, popupWidth + toolBar.height + acceptButton.height)
  x: (parent.width - width) / 2
  y: (parent.height - height) / 2
  z: 10000 // 1000s are embedded feature forms, use a higher value to insure feature form popups always show above embedded feature formes
  padding: 0

  closePolicy: Popup.CloseOnEscape
  dim: true

  onAboutToShow: {
    openedOnce = true
    // when NFC is not accessible, make sure the only option, QR, is active
    if (!withNfc && !settings.cameraActive) {
      settings.cameraActive = true
    }
    barcodeDecoder.clearDecodedString();
  }

  onAboutToHide: {
    if (cameraLoader.active) {
      cameraLoader.item.flash.mode = Camera.FlashOff;
    }
  }

  Settings {
    id: settings
    property bool cameraActive: true
    property bool nearfieldActive: true
  }

  BarcodeDecoder {
    id: barcodeDecoder

    onDecodedStringChanged: {
      if (decodedString !== '') {
        codeReader.decodedString = decodedString
        decodedFlashAnimation.start();
      }
    }
  }

  Loader {
    id: nearfieldLoader
    active: withNfc && codeReader.openedOnce && settings.nearfieldActive

    sourceComponent: Component {
      Item {
        id: nearFieldContainer

        Component.onCompleted: {
          Qt.createQmlObject('import org.qfield 1.0
            NearFieldReader {
              active: codeReader.visible
              onTargetDetected: (targetId) => {
                displayToast(qsTr(\'NFC tag detected\'))
              }
              onReadStringChanged: {
                if (readString !== \'\') {
                  codeReader.decodedString = readString
                  decodedFlashAnimation.start();
                }
              }
            }' , nearFieldContainer);
        }
      }
    }
  }

  Loader {
    id: cameraLoader
    active: codeReader.openedOnce && settings.cameraActive
    sourceComponent: Component {

      Camera {
        id: camera
        position: Camera.BackFace
        cameraState: codeReader.visible ? Camera.ActiveState : Camera.UnloadedState

        focus {
          focusMode: Camera.FocusContinuous
          focusPointMode: Camera.FocusPointCenter
        }

        flash.mode: Camera.FlashOff

        Component.onCompleted: {
          videoOutput.source = camera
        }
      }
    }
  }


  Page {
    width: parent.width
    height: parent.height
    padding: 10
    header: ToolBar {
      id: toolBar

      background: Rectangle {
        color: "transparent"
        height: 48
      }

      RowLayout {
        width: parent.width
        height: 48

        Label {
          Layout.leftMargin: 58
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          text: qsTr('Code Reader')
          font: Theme.strongFont
          color: Theme.mainColor
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }

        QfToolButton {
          id: closeButton
          Layout.rightMargin: 10
          Layout.alignment: Qt.AlignVCenter
          iconSource: Theme.getThemeIcon( 'ic_close_black_24dp' )
          iconColor: Theme.mainTextColor
          bgcolor: "transparent"

          onClicked: {
            codeReader.close();
          }
        }
      }
    }

    ColumnLayout {
      width: parent.width
      height: parent.height

      Rectangle {
        id: visualFeedback
        Layout.fillWidth: true
        Layout.fillHeight: true

        color: Theme.mainBackgroundColor
        radius: 10
        clip: true

        Rectangle {
          id: nearfieldFeedback
          visible: settings.nearfieldActive && !settings.cameraActive
          anchors.centerIn: parent
          width: 120
          height: width
          radius: width / 2
          color: "#44808080"

          SequentialAnimation {
            NumberAnimation {
              target:  nearfieldFeedback
              property: "width"
              to: 120 + (Math.min(visualFeedback.width, visualFeedback.height) - 120)
              duration: 2000
              easing.type: Easing.InOutQuad
            }
            NumberAnimation {
              target:  nearfieldFeedback
              property: "width"
              to: 120
              duration: 2000
              easing.type: Easing.InOutQuad
            }
            running: nearfieldFeedback.visible
            loops: Animation.Infinite
          }
        }

        VideoOutput {
          id: videoOutput
          visible: settings.cameraActive

          anchors.fill: parent
          anchors.margins: 6

          autoOrientation: true
          fillMode: VideoOutput.PreserveAspectCrop

          filters: [
            BarcodeVideoFilter {
              active: codeReader.visible
              decoder: barcodeDecoder
            }
          ]
        }

        Rectangle {
          id: decodedFlash
          anchors.fill: parent
          anchors.margins: 6

          color: "transparent"
          SequentialAnimation {
            id: decodedFlashAnimation
            PropertyAnimation { target: decodedFlash; property: "color"; to: "white"; duration: 0 }
            PropertyAnimation { target: decodedFlash; property: "color"; to: "transparent"; duration: 500 }
          }
        }

        Shape {
          id: frame
          visible: settings.cameraActive
          anchors.fill: parent

          ShapePath {
            strokeWidth: 2.5
            strokeColor: "#333333"
            strokeStyle: ShapePath.SolidLine
            joinStyle: ShapePath.MiterJoin
            fillColor: "transparent"

            startX: 5
            startY: 10
            PathArc { x: 10; y: 5; radiusX: 5; radiusY: 5 }
            PathLine { x: frame.width - 10; y: 5; }
            PathArc { x: frame.width - 5; y: 10; radiusX: 5; radiusY: 5 }
            PathLine { x: frame.width - 5; y: frame.height - 10; }
            PathArc { x: frame.width - 10; y: frame.height - 5; radiusX: 5; radiusY: 5 }
            PathLine { x: 10; y: frame.height - 5; }
            PathArc { x: 5; y: frame.height - 10; radiusX: 5; radiusY: 5 }
            PathLine { x: 5; y: 10 }
          }
        }

        Shape {
          id: aim
          visible: settings.cameraActive
          anchors.fill: parent

          ShapePath {
            strokeWidth: 2.5
            strokeColor: "white"
            strokeStyle: ShapePath.SolidLine
            joinStyle: ShapePath.MiterJoin
            fillColor: "transparent"

            startX: 20
            startY: 60
            PathLine { x: 20; y: 25 }
            PathArc { x: 25; y: 20; radiusX: 5; radiusY: 5 }
            PathLine { x: 60; y: 20 }
            PathMove { x: aim.width - 60; y: 20 }
            PathLine { x: aim.width - 25; y: 20 }
            PathArc { x: aim.width - 20; y: 25; radiusX: 5; radiusY: 5; }
            PathLine { x: aim.width - 20; y: 60 }
            PathMove { x: aim.width - 20; y: aim.height - 60 }
            PathLine { x: aim.width - 20; y: aim.height - 25 }
            PathArc { x: aim.width - 25; y: aim.height - 20; radiusX: 5; radiusY: 5 }
            PathLine { x: aim.width - 60; y: aim.height - 20 }
            PathMove { x: 60; y: aim.height - 20 }
            PathLine { x: 25; y: aim.height - 20 }
            PathArc { x: 20; y: aim.height - 25; radiusX: 5; radiusY: 5 }
            PathLine { x: 20; y: aim.height - 60; }
          }
        }

        QfToolButton {
          id: flashlightButton
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 20
          anchors.horizontalCenter: parent.horizontalCenter
          round: true
          iconSource: Theme.getThemeVectorIcon( 'ic_flashlight_white_48dp' )
          iconColor: "white"
          bgcolor: Qt.hsla(Theme.darkGray.hslHue, Theme.darkGray.hslSaturation, Theme.darkGray.hslLightness, 0.3)

          visible: cameraLoader.active && cameraLoader.item.flash.supportedModes.includes(Camera.FlashVideoLight)
          state: cameraLoader.active && cameraLoader.item.flash.mode !== Camera.FlashOff ? "On" : "Off"
          states: [
            State {
              name: "Off"
              PropertyChanges {
                target: flashlightButton
                iconColor: "white"
                bgcolor: Qt.hsla(Theme.darkGray.hslHue, Theme.darkGray.hslSaturation, Theme.darkGray.hslLightness, 0.3)
              }
            },

            State {
              name: "On"
              PropertyChanges {
                target: flashlightButton
                iconColor: Theme.mainColor
                bgcolor: Theme.darkGray
              }
            }
          ]

          onClicked: {
            cameraLoader.item.flash.mode = camera.flash.mode === Camera.FlashOff
                                           ? Camera.FlashVideoLight
                                           : Camera.FlashOff;
          }
        }

        QfToolButton {
          id: cameraButton
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 20
          anchors.right: flashlightButton.left
          anchors.rightMargin: 10
          round: true
          iconSource: Theme.getThemeVectorIcon( 'ic_qr_code_black_24dp' )
          iconColor: "white"
          bgcolor: Qt.hsla(Theme.darkGray.hslHue, Theme.darkGray.hslSaturation, Theme.darkGray.hslLightness, 0.3)

          visible: withNfc
          state: settings.cameraActive ? "On" : "Off"
          states: [
            State {
              name: "Off"
              PropertyChanges {
                target: cameraButton
                bgcolor: Qt.hsla(Theme.darkGray.hslHue, Theme.darkGray.hslSaturation, Theme.darkGray.hslLightness, 0.3)
              }
            },

            State {
              name: "On"
              PropertyChanges {
                target: cameraButton
                iconColor: Theme.mainColor
                bgcolor: Theme.darkGray
              }
            }
          ]

          onClicked: {
            settings.cameraActive = !settings.cameraActive;
          }
        }

        QfToolButton {
          id: nearfieldButton
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 20
          anchors.left: flashlightButton.right
          round: true
          iconSource: Theme.getThemeVectorIcon( 'ic_nfc_code_black_24dp' )
          iconColor: "white"
          bgcolor: Qt.hsla(Theme.darkGray.hslHue, Theme.darkGray.hslSaturation, Theme.darkGray.hslLightness, 0.3)

          visible: withNfc
          state: settings.nearfieldActive ? "On" : "Off"
          states: [
            State {
              name: "Off"
              PropertyChanges {
                target: nearfieldButton
                bgcolor: Qt.hsla(Theme.darkGray.hslHue, Theme.darkGray.hslSaturation, Theme.darkGray.hslLightness, 0.3)
              }
            },

            State {
              name: "On"
              PropertyChanges {
                target: nearfieldButton
                iconColor: Theme.mainColor
                bgcolor: Theme.darkGray
              }
            }
          ]

          onClicked: {
            settings.nearfieldActive = !settings.nearfieldActive;
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true

        Text {
          id: decodedText
          Layout.fillWidth: true

          text: codeReader.decodedString !== ''
                ? codeReader.decodedString
                : qsTr( 'Center your device on a code')
          font: Theme.tipFont
          color: Theme.mainTextColor
          horizontalAlignment: Text.AlignLeft
          elide: Text.ElideMiddle
          opacity: codeReader.decodedString !== '' ? 1 : 0.45
        }

        QfToolButton {
          id: acceptButton
          enabled: codeReader.decodedString !== ''
          opacity: enabled ? 1 : 0.2
          Layout.alignment: Qt.AlignVCenter
          iconSource: Theme.getThemeIcon( 'ic_check_black_48dp' )
          iconColor: enabled ? "white" : Theme.mainTextColor
          bgcolor: enabled ? Theme.mainColor : "transparent"
          round: true

          onClicked: {
            if (codeReader.barcodeRequestedItem != undefined) {
                codeReader.barcodeRequestedItem.requestedBarcodeReceived(codeReader.decodedString)
                codeReader.barcodeRequestedItem = undefined;
            } else {
                codeReader.decoded(codeReader.decodedString);
            }
            codeReader.close();
          }
        }
      }
    }
  }
}
