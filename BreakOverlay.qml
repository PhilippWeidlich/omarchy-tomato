import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// Vollbild-Pause (optional, ab Werk aus). Liegt über allem auf dem Monitor
// dieser Leiste und nimmt Maus und Tastatur. Notausgang: Esc 3 Sekunden halten.
PanelWindow {
  id: win
  property var pomo: null
  property bool shown: false

  visible: shown
  color: "transparent"
  anchors { top: true; left: true; right: true; bottom: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "tomato-break"
  WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  readonly property color fg: Commons.Color.foreground
  readonly property color bg: Commons.Color.background

  onShownChanged: if (shown) Qt.callLater(function() { keys.forceActiveFocus() })

  Rectangle {
    id: backdrop
    anchors.fill: parent
    color: Qt.rgba(win.bg.r, win.bg.g, win.bg.b, 0.96)
    opacity: win.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Style.duration(250); easing.type: Easing.OutCubic } }

    // Klicks schlucken, damit nichts darunter erreichbar ist
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true }

    Column {
      anchors.centerIn: parent
      spacing: Style.space(18)
      scale: win.shown ? 1 : 0.96
      Behavior on scale { NumberAnimation { duration: Style.duration(250); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }

      TomatoIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(140)
        height: width
        mode: 2
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: win.pomo ? win.pomo.phaseName(win.pomo.phase) : ""
        color: "#5bb974"
        font.family: Style.font.family
        font.pixelSize: Style.font.body * 2
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: {
          if (!win.pomo) return ""
          var sec = Math.max(0, Math.ceil(win.pomo.remainingMs / 1000))
          var m = Math.floor(sec / 60), s = sec % 60
          return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
        }
        color: win.fg
        font.family: Style.font.family
        font.pixelSize: Style.font.body * 7
        font.bold: true
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(420)
        height: Style.space(6)
        radius: height / 2
        color: Qt.rgba(win.fg.r, win.fg.g, win.fg.b, 0.12)
        Rectangle {
          width: parent.width * (win.pomo ? win.pomo.progress : 0)
          height: parent.height
          radius: parent.radius
          color: "#5bb974"
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: win.pomo ? win.pomo.tr.t("overlay.tip") : ""
        color: win.fg
        opacity: 0.75
        font.family: Style.font.family
        font.pixelSize: Style.font.body * 1.2
      }

      Item { width: 1; height: Style.space(30) }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: win.pomo ? win.pomo.tr.t("overlay.escape") : ""
        color: win.fg
        opacity: 0.4
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(160)
        height: Style.space(3)
        radius: height / 2
        color: Qt.rgba(win.fg.r, win.fg.g, win.fg.b, 0.1)
        Rectangle {
          id: holdBar
          height: parent.height
          radius: parent.radius
          color: "#e5484d"
          width: 0
        }
      }
    }
  }

  NumberAnimation {
    id: hold
    target: holdBar
    property: "width"
    from: 0
    to: Style.space(160)
    duration: 3000
    onFinished: if (holdBar.width >= Style.space(160) - 1 && win.pomo) win.pomo.dismissOverlay()
  }

  Item {
    id: keys
    anchors.fill: parent
    focus: true
    Keys.onPressed: function(e) {
      if (e.key === Qt.Key_Escape && !e.isAutoRepeat) hold.restart()
      e.accepted = true
    }
    Keys.onReleased: function(e) {
      if (e.key === Qt.Key_Escape && !e.isAutoRepeat) { hold.stop(); holdBar.width = 0 }
      e.accepted = true
    }
  }
}
