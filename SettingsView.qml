import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Einstellungen: Zeiten, Vorlagen und alle Funktionen als Kachel mit Text.
// Jedes Extra ist ab Werk aus und muss selbst eingeschaltet werden.
Column {
  id: view
  property var pomo: null
  spacing: Style.space(8)

  readonly property color fg: Commons.Color.foreground
  readonly property color red: "#e5484d"
  readonly property var s: pomo ? pomo.settings : ({})

  function t(key) { return pomo ? pomo.tr.t(key) : "" }
  function set(key, value) { pomo.setSetting(key, value) }

  function setMany(obj) {
    var next = Model.copy(pomo.settings)
    for (var k in obj) next[k] = obj[k]
    pomo.writeSettings(next)
  }

  // ---------- Sprache ----------
  Text {
    textFormat: Text.PlainText
    text: "󰗊  " + view.t("set.language")
    color: view.fg
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.bold: true
  }

  ButtonGroup {
    width: parent.width
    options: [
      { value: "auto", label: view.t("lang.auto") },
      { value: "de", label: "Deutsch" },
      { value: "en", label: "English" }
    ]
    value: view.s.language || "auto"
    onChanged: function(v) { view.set("language", v) }
  }

  PanelSeparator { width: parent.width }

  // ---------- Grundeinstellungen ----------
  Stepper { width: parent.width; host: view; label: view.t("set.work"); key: "work"; from: 1; to: 180 }
  Stepper { width: parent.width; host: view; label: view.t("set.shortBreak"); key: "shortBreak"; from: 1; to: 60 }
  Stepper { width: parent.width; host: view; label: view.t("set.longBreak"); key: "longBreak"; from: 1; to: 120 }
  Stepper { width: parent.width; host: view; label: view.t("set.interval"); key: "interval"; from: 1; to: 12; unit: "sessions" }
  Stepper { width: parent.width; host: view; label: view.t("set.dailyGoal"); key: "dailyGoal"; from: 1; to: 30; unit: "sessions" }

  Text {
    textFormat: Text.PlainText
    text: view.t("set.presets")
    color: view.fg
    opacity: 0.7
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }

  Flow {
    width: parent.width
    spacing: Style.space(6)
    Repeater {
      model: [[25, 5, 15], [50, 10, 30], [90, 20, 30]]
      Button {
        bordered: true
        text: modelData[0] + " / " + modelData[1] + " / " + modelData[2]
        selected: view.s.work === modelData[0] && view.s.shortBreak === modelData[1] && view.s.longBreak === modelData[2]
        onClicked: view.setMany({ work: modelData[0], shortBreak: modelData[1], longBreak: modelData[2] })
      }
    }
  }

  PanelSeparator { width: parent.width }

  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    text: view.t("set.features")
    color: view.fg
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.bold: true
  }

  // Stil aktiver Kacheln
  Row {
    spacing: Style.space(8)
    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: view.t("set.tileStyle")
      color: view.fg
      opacity: 0.7
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    ButtonGroup {
      options: [
        { value: "neutral", label: view.t("set.tileNeutral") },
        { value: "red", label: view.t("set.tileRed") }
      ]
      value: view.s.tileStyle || "neutral"
      onChanged: function(v) { view.set("tileStyle", v) }
    }
  }

  // Alle Funktionen als Kachel + Text (ab Werk aus, außer Benachrichtigung)
  Repeater {
    model: Model.TILES

    Column {
      width: parent.width
      spacing: Style.space(6)
      readonly property bool on: view.s[modelData.id] === true

      Item {
        width: parent.width
        implicitHeight: Math.max(square.height, texts.implicitHeight)

        Rectangle {
          id: square
          width: Style.space(36)
          height: width
          radius: Style.cornerRadius > 0 ? Style.space(6) : 0
          readonly property color onColor: view.s.tileStyle === "red" ? view.red : view.fg
          color: parent.parent.on ? Qt.rgba(onColor.r, onColor.g, onColor.b, view.s.tileStyle === "red" ? 0.2 : 0.14) : Qt.rgba(view.fg.r, view.fg.g, view.fg.b, 0.03)
          border.width: 1
          border.color: parent.parent.on ? Qt.rgba(onColor.r, onColor.g, onColor.b, view.s.tileStyle === "red" ? 0.9 : 0.55) : Qt.rgba(view.fg.r, view.fg.g, view.fg.b, 0.15)
          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: modelData.glyph
            color: parent.parent.parent.on ? parent.onColor : view.fg
            opacity: parent.parent.parent.on ? 1 : 0.35
            font.family: Style.font.family
            font.pixelSize: Style.font.body * 1.1
          }
        }

        Column {
          id: texts
          anchors.left: square.right
          anchors.leftMargin: Style.space(10)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)
          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: view.t("item." + modelData.id + ".title") + "  ·  " + (parent.parent.parent.on ? view.t("state.on") : view.t("state.off"))
            color: view.fg
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: view.t("item." + modelData.id + ".desc")
            color: view.fg
            opacity: 0.6
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: view.set(modelData.id, !parent.parent.on)
        }
      }

      // Tonauswahl
      Flow {
        width: parent.width
        leftPadding: Style.space(46)
        spacing: Style.space(6)
        visible: modelData.id === "sound" && parent.on
        Repeater {
          model: Model.SOUNDS
          Button {
            bordered: true
            selected: view.s.soundName === modelData
            text: view.t("sound." + modelData)
            onClicked: { view.set("soundName", modelData); view.pomo.playSound(modelData) }
          }
        }
      }

      Text {
        visible: modelData.id === "fullscreenBreak"
        width: parent.width
        leftPadding: Style.space(46)
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: view.t("set.fullscreenWarn")
        color: view.red
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        visible: modelData.id === "replayMissed" && parent.on && view.s.focusDnd !== true
        width: parent.width
        leftPadding: Style.space(46)
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: view.t("set.replayNeedsDnd")
        color: view.fg
        opacity: 0.6
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  Button {
    bordered: true
    text: view.t("set.defaults")
    onClicked: view.pomo.writeSettings({ boxes: view.pomo.settings.boxes })
  }
}
