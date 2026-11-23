import QtQuick
import qs.Commons
import qs.Commons as Commons

// Erklärung zu einem Hover-Schlüssel ("tile:<id>", "btn:…", "help", …).
Column {
  id: info
  property var host: null
  property string key: ""
  property int align: Text.AlignHCenter
  spacing: Style.space(3)

  readonly property var pomo: host ? host.pomo : null
  readonly property string tileId: key.indexOf("tile:") === 0 ? key.slice(5) : ""
  readonly property color fg: Commons.Color.foreground
  function t(k) { return pomo ? pomo.tr.t(k) : "" }

  Text {
    width: parent.width
    horizontalAlignment: info.align
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: info.fg
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.bold: true
    text: info.tileId ? info.t("item." + info.tileId + ".title") + "  ·  "
        + (info.pomo && info.pomo.settings[info.tileId] === true ? info.t("state.on") : info.t("state.off"))
      : info.t("info." + info.key.replace(":", ".") + ".title")
  }
  Text {
    width: parent.width
    horizontalAlignment: info.align
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: info.fg
    opacity: 0.7
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    text: info.tileId ? info.t("item." + info.tileId + ".desc") : info.t("info." + info.key.replace(":", ".") + ".desc")
  }
  Text {
    visible: info.tileId === "fullscreenBreak"
    width: parent.width
    horizontalAlignment: info.align
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: "#e5484d"
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    text: info.t("set.fullscreenWarn")
  }
}
