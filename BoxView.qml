import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Ein Feld links oder rechts der Zeit. Zeigt Kacheln (2x2 / 3x3),
// die Timer-Aufteilung, eine kleine Statistik oder einen Mini-Kalender.
// Beim Anpassen: Rastergröße und Inhalt über kleine Knöpfe darunter.
Column {
  id: boxView
  property var host: null
  property string side: "left"
  property real boxSize: Style.space(132)
  spacing: Style.space(6)

  readonly property var pomo: host ? host.pomo : null
  readonly property var box: pomo && pomo.settings && pomo.settings.boxes ? pomo.settings.boxes[side] : Model.DEFAULT_BOXES[side]
  readonly property bool editing: host ? host.customizing : false
  readonly property color fg: Commons.Color.foreground
  readonly property real gap: Style.space(box.size === 3 ? 5 : 8)
  readonly property real tileSize: (boxSize - gap * (box.size - 1)) / box.size

  function t(key) { return pomo ? pomo.tr.t(key) : "" }

  Rectangle {
    width: boxView.boxSize
    height: boxView.boxSize
    radius: Style.cornerRadius > 0 ? Style.space(8) : 0
    color: "transparent"
    border.width: boxView.editing && boxView.box.mode !== "tiles" ? 1 : 0
    border.color: Qt.rgba(boxView.fg.r, boxView.fg.g, boxView.fg.b, 0.2)

    // ---------- Kacheln ----------
    Grid {
      visible: boxView.box.mode === "tiles"
      columns: boxView.box.size
      spacing: boxView.gap

      Repeater {
        model: boxView.box.size * boxView.box.size
        Item {
          id: slot
          width: boxView.tileSize
          height: boxView.tileSize
          readonly property string tileId: boxView.box.slots[index] || ""
          readonly property int slotIndex: index

          // leerer Platz – nur beim Anpassen sichtbar
          Rectangle {
            anchors.fill: parent
            visible: boxView.editing && parent.tileId === ""
            radius: Style.cornerRadius > 0 ? Style.space(6) : 0
            color: slotDrop.containsDrag ? Qt.rgba(boxView.fg.r, boxView.fg.g, boxView.fg.b, 0.12) : "transparent"
            border.width: 1
            border.color: Qt.rgba(boxView.fg.r, boxView.fg.g, boxView.fg.b, slotDrop.containsDrag ? 0.6 : 0.15)
          }

          Tile {
            visible: slot.tileId !== ""
            host: boxView.host
            dropLayer: boxView.host ? boxView.host.dragLayer : null
            tileId: slot.tileId
            side: boxView.side
            index: slot.slotIndex
            size: boxView.tileSize
          }

          Rectangle {
            anchors.fill: parent
            visible: slotDrop.containsDrag && parent.tileId !== ""
            color: "transparent"
            radius: Style.cornerRadius > 0 ? Style.space(6) : 0
            border.width: 2
            border.color: boxView.fg
          }

          DropArea {
            id: slotDrop
            anchors.fill: parent
            keys: ["pomo-tile"]
            enabled: boxView.editing
            onDropped: function(d) {
              var src = d.source
              var from = src.fromIndex >= 0 ? { side: src.fromSide, index: src.fromIndex } : null
              var id = src.tileId, sd = boxView.side, i = index
              Qt.callLater(function() { boxView.host.placeTile(id, sd, i, from) })
            }
          }
        }
      }
    }

    // ---------- Timer-Aufteilung ----------
    Column {
      visible: boxView.box.mode === "timer"
      anchors.fill: parent
      anchors.margins: Style.space(6)
      spacing: Style.space(2)

      Repeater {
        model: [
          { key: "work", label: "set.work", from: 1, to: 180 },
          { key: "shortBreak", label: "set.shortBreak", from: 1, to: 60 },
          { key: "longBreak", label: "set.longBreak", from: 1, to: 120 },
          { key: "interval", label: "box.every", from: 1, to: 12 }
        ]
        Item {
          width: parent.width
          height: Style.space(28)
          readonly property int value: boxView.pomo && boxView.pomo.settings ? (boxView.pomo.settings[modelData.key] || 0) : 0
          function change(d) {
            var v = Math.max(modelData.from, Math.min(modelData.to, value + d))
            if (v !== value) boxView.pomo.setSetting(modelData.key, v)
          }
          Text {
            anchors.left: parent.left
            anchors.right: ctl.left
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideNone
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: boxView.t(modelData.label)
            color: boxView.fg
            opacity: 0.7
            font.family: Style.font.family
            font.pixelSize: Style.font.caption * 0.9
          }
          Row {
            id: ctl
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              textFormat: Text.PlainText; text: "−"; color: boxView.fg
              font.family: Style.font.family; font.pixelSize: Style.font.body
              MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.parent.change(-1) }
            }
            Text {
              width: Style.space(22)
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText; text: String(parent.parent.value); color: boxView.fg
              font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true
              MouseArea { anchors.fill: parent; onWheel: function(w) { parent.parent.parent.change(w.angleDelta.y > 0 ? 1 : -1) } }
            }
            Text {
              textFormat: Text.PlainText; text: "+"; color: boxView.fg
              font.family: Style.font.family; font.pixelSize: Style.font.body
              MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.parent.change(1) }
            }
          }
        }
      }
    }

    // ---------- Statistik ----------
    Column {
      visible: boxView.box.mode === "stats"
      anchors.fill: parent
      anchors.margins: Style.space(6)
      spacing: Style.space(6)

      Repeater {
        model: [
          { k: "hist.today", v: boxView.pomo ? boxView.pomo.stats.today : null },
          { k: "hist.week", v: boxView.pomo ? boxView.pomo.stats.week : null },
          { k: "hist.month", v: boxView.pomo ? boxView.pomo.stats.month : null }
        ]
        Item {
          width: parent.width
          height: Style.space(24)
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: boxView.t(modelData.k)
            color: boxView.fg; opacity: 0.6
            font.family: Style.font.family; font.pixelSize: Style.font.caption
          }
          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: modelData.v ? "🍅 " + modelData.v.done : ""
            color: boxView.fg
            font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true
          }
        }
      }

      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        visible: boxView.pomo && boxView.pomo.stats.streak > 0
        text: boxView.pomo ? "🔥 " + boxView.pomo.tr.tn("hist.streak", boxView.pomo.stats.streak).arg(boxView.pomo.stats.streak) : ""
        color: boxView.fg; opacity: 0.7
        font.family: Style.font.family; font.pixelSize: Style.font.caption
      }
    }

    // ---------- Mini-Kalender ----------
    Column {
      visible: boxView.box.mode === "calendar"
      anchors.fill: parent
      anchors.margins: Style.space(4)
      spacing: Style.space(4)

      readonly property var cells: boxView.pomo && visible
        ? Model.monthGrid(boxView.pomo.history, new Date(boxView.pomo.now).getFullYear(), new Date(boxView.pomo.now).getMonth(), boxView.pomo.now) : []

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: boxView.pomo ? boxView.pomo.loc.toString(new Date(boxView.pomo.now), "MMMM") : ""
        color: boxView.fg; opacity: 0.7
        font.family: Style.font.family; font.pixelSize: Style.font.caption
      }

      Grid {
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 7
        spacing: Style.space(3)
        Repeater {
          model: parent.parent.cells
          Rectangle {
            readonly property real cell: (boxView.boxSize - Style.space(8) - Style.space(18)) / 7
            width: cell
            height: cell * 0.8
            radius: Style.space(2)
            opacity: modelData.inMonth ? 1 : 0.25
            color: modelData.done > 0 ? Qt.rgba(0.9, 0.28, 0.3, 0.25 + 0.75 * modelData.level)
              : Qt.rgba(boxView.fg.r, boxView.fg.g, boxView.fg.b, 0.08)
            border.width: modelData.isToday ? 1 : 0
            border.color: boxView.fg
          }
        }
      }
    }

    // Feld anklicken (außer Kacheln/Timer) öffnet den Verlauf
    MouseArea {
      anchors.fill: parent
      visible: !boxView.editing && (boxView.box.mode === "stats" || boxView.box.mode === "calendar")
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: boxView.host.info = "box:" + boxView.box.mode
      onExited: if (boxView.host.info === "box:" + boxView.box.mode) boxView.host.info = ""
      onClicked: boxView.host.openSettings("history")
    }
  }

  // ---------- Knöpfe beim Anpassen ----------
  Row {
    visible: boxView.editing
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.space(4)

    Button {
      visible: boxView.box.mode === "tiles"
      bordered: true
      text: boxView.box.size === 2 ? "2×2" : "3×3"
      onClicked: boxView.host.resizeBox(boxView.side)
      onHovered: function(h) { boxView.host.info = h ? "edit:size" : "" }
    }
    Button {
      bordered: true
      iconText: Model.BOX_MODE_GLYPHS[boxView.box.mode]
      text: boxView.t("box.mode." + boxView.box.mode)
      onClicked: boxView.host.cycleBoxMode(boxView.side)
      onHovered: function(h) { boxView.host.info = h ? "edit:mode" : "" }
    }
  }
}
