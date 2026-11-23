import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// Quadratische Kachel = ein Schalter. Aus: blass · an: kräftig.
// Erklärung erscheint beim Drüberfahren unten im Statusbereich (host.info).
// Beim Anpassen ziehbar; side/index = Herkunft (index -1 = Baukasten).
Item {
  id: holder
  property var host: null
  property var dropLayer: null
  property string tileId: ""
  property string side: ""
  property int index: -1
  property real size: Style.space(40)

  readonly property var def: Model.tile(tileId)
  readonly property bool on: host && host.pomo ? host.pomo.settings[tileId] === true : false
  readonly property bool editing: host ? host.customizing : false
  readonly property color fg: Commons.Color.foreground
  readonly property bool redStyle: host && host.pomo ? host.pomo.settings.tileStyle === "red" : false
  // Farbe einer aktiven Kachel: neutral = Vordergrund, rot = Tomatenrot
  readonly property color onColor: redStyle ? "#e5484d" : fg

  implicitWidth: size
  implicitHeight: size

  Rectangle {
    id: chip
    property string tileId: holder.tileId
    property string fromSide: holder.side
    property int fromIndex: holder.index

    width: holder.size
    height: holder.size
    radius: Style.cornerRadius > 0 ? Style.space(6) : 0
    color: holder.on && !ma.drag.active
      ? Qt.rgba(holder.onColor.r, holder.onColor.g, holder.onColor.b, holder.redStyle ? 0.2 : 0.14)
      : Qt.rgba(holder.fg.r, holder.fg.g, holder.fg.b, ma.drag.active ? 0.2 : (ma.containsMouse ? 0.08 : 0.03))
    border.width: 1
    border.color: holder.on ? Qt.rgba(holder.onColor.r, holder.onColor.g, holder.onColor.b, holder.redStyle ? 0.9 : 0.55)
      : Qt.rgba(holder.fg.r, holder.fg.g, holder.fg.b, ma.containsMouse ? 0.35 : 0.15)
    Behavior on color { ColorAnimation { duration: Style.duration(120) } }

    HoverHandler { id: hov }

    Drag.active: ma.drag.active
    Drag.keys: ["pomo-tile"]
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    states: State {
      when: ma.drag.active
      ParentChange { target: chip; parent: holder.dropLayer }
    }

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: holder.def ? holder.def.glyph : ""
      color: holder.on ? holder.onColor : holder.fg
      opacity: holder.on ? 1 : 0.35
      font.family: Style.font.family
      font.pixelSize: Math.round(holder.size * 0.42)
    }

    MouseArea {
      id: ma
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: holder.editing ? (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
      drag.target: holder.editing ? chip : null
      onEntered: holder.host.info = "tile:" + holder.tileId
      onExited: if (holder.host.info === "tile:" + holder.tileId) holder.host.info = ""
      onClicked: {
        if (!holder.editing) holder.host.pomo.setSetting(holder.tileId, !holder.on)
        else if (holder.index < 0) holder.host.addTile(holder.tileId)
      }
      onReleased: {
        if (drag.active) chip.Drag.drop()
        chip.x = 0
        chip.y = 0
      }
    }

    // ✕ zum Entfernen beim Anpassen
    Rectangle {
      visible: holder.editing && holder.index >= 0 && hov.hovered && !ma.drag.active
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: -Style.space(4)
      width: Style.space(16)
      height: width
      radius: width / 2
      color: "#e5484d"
      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: "✕"
        color: "white"
        font.pixelSize: Style.space(9)
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { var id = holder.tileId; Qt.callLater(function() { holder.host.removeTile(id) }) }
      }
    }
  }
}
