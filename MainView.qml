import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Hauptkarte:
//   [Feld links]   Phase · aktive Funktionen · ZEIT · ▶ ↺ ⏭   [Feld rechts]
//   ────────────────────────── 🍅 ──────────────────────────
//                   Status (?) · Heute · Runde          [✎][⚙]
// Erklärungen erscheinen beim Drüberfahren unten im Statusbereich.
Item {
  id: view
  property var pomo: null
  property string info: ""
  property bool helpPinned: false
  readonly property bool customizing: pomo ? pomo.customizing : false
  property alias dragLayer: dragLayerItem

  implicitHeight: col.implicitHeight

  readonly property color fg: Commons.Color.foreground
  readonly property color red: "#e5484d"
  readonly property real boxSize: Style.space(132)
  readonly property color phaseColor: !pomo ? fg : (pomo.idle && pomo.isWork ? fg : pomo.phaseColor(pomo.phase))

  function t(key) { return pomo ? pomo.tr.t(key) : "" }

  function saveBoxes(b) { pomo.setSetting("boxes", b) }
  function placeTile(id, side, index, from) { saveBoxes(Model.placeTile(pomo.settings.boxes, id, side, index, from)) }
  function removeTile(id) { saveBoxes(Model.removeTile(pomo.settings.boxes, id)) }
  function resizeBox(side) { saveBoxes(Model.resizeBox(pomo.settings.boxes, side)) }
  function cycleBoxMode(side) { saveBoxes(Model.cycleBoxMode(pomo.settings.boxes, side)) }
  function openSettings(tab) { pomo.customizing = false; pomo.tab = tab; pomo.page = "settings" }

  // Kachel aus dem Baukasten in den ersten freien Platz legen
  function addTile(id) {
    var b = pomo.settings.boxes
    var sides = ["left", "right"]
    for (var s = 0; s < 2; s++) {
      var box = b[sides[s]]
      if (box.mode !== "tiles") continue
      for (var i = 0; i < box.size * box.size; i++)
        if (!box.slots[i]) { placeTile(id, sides[s], i, null); return }
    }
  }

  function clockOf(sec) {
    sec = Math.max(0, sec)
    var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60
    function p(n) { return n < 10 ? "0" + n : "" + n }
    return (h > 0 ? h + ":" + p(m) : p(m)) + ":" + p(s)
  }

  readonly property string activeAttributes: {
    if (!pomo) return ""
    var parts = []
    for (var i = 0; i < Model.TILES.length; i++) {
      var tl = Model.TILES[i]
      // feste Leerzeichen: Symbol und Name bleiben beim Umbruch zusammen
      if (pomo.settings[tl.id] === true) parts.push((tl.glyph + " " + t("item." + tl.id + ".title")).replace(/ /g, "\u00A0"))
    }
    return parts.join("   ")
  }

  // Tomatenstücke hinter dem Inhalt
  Pieces {
    id: pieces
    x: 0
    y: 0
    width: view.width
    height: card.height
    active: view.pomo ? view.pomo.done : false
    seed: view.pomo ? view.pomo.st.startMs : 1
    originX: width / 2
    originY: line.y + line.height / 2
    Connections {
      target: view
      function onVisibleChanged() { if (view.visible) pieces.play() }
    }
  }

  Column {
    id: col
    width: parent.width
    spacing: Style.space(12)

    Item {
      id: card
      width: parent.width
      implicitHeight: cardCol.implicitHeight

      Column {
        id: cardCol
        width: parent.width
        spacing: Style.space(6)

        // ---------- oben: Feld · Mitte · Feld ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(leftBox.implicitHeight, center.implicitHeight, rightBox.implicitHeight)

          BoxView {
            id: leftBox
            anchors.left: parent.left
            host: view
            side: "left"
            boxSize: view.boxSize
          }

          Column {
            id: center
            anchors.left: leftBox.right
            anchors.right: rightBox.left
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: view.pomo ? view.pomo.phaseName(view.pomo.done ? "work" : view.pomo.phase) : ""
              color: view.phaseColor
              font.family: Style.font.family
              font.pixelSize: Style.font.body * 1.1
              font.bold: true
            }

            // aktive Funktionen
            Text {
              width: parent.width
              visible: text !== ""
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: view.activeAttributes
              color: view.fg
              opacity: 0.5
              font.family: Style.font.family
              font.pixelSize: Style.font.caption * 0.9
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: !view.pomo ? "" : view.pomo.done ? view.t("doneBig") : view.clockOf(Math.ceil(view.pomo.remainingMs / 1000))
              color: view.pomo && (view.pomo.active || view.pomo.done) ? view.phaseColor : view.fg
              opacity: view.pomo && view.pomo.paused ? 0.55 : 1
              font.family: Style.font.family
              font.pixelSize: Style.font.body * 3.4
              font.bold: true
            }

            // ▶ / ⏸ · ↺ · ⏭
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(6)

              Button {
                bordered: true
                iconText: view.pomo && view.pomo.running ? "󰏤" : "󰐊"
                onClicked: view.pomo.primary()
                onHovered: function(h) { view.info = h ? "btn:primary" : "" }
              }
              Button {
                bordered: true
                iconText: "󰑓"
                onClicked: view.pomo.reset()
                onHovered: function(h) { view.info = h ? "btn:reset" : "" }
              }
              Button {
                bordered: true
                iconText: "󰒭"
                onClicked: view.pomo.skip()
                onHovered: function(h) { view.info = h ? "btn:skip" : "" }
              }
            }
          }

          BoxView {
            id: rightBox
            anchors.right: parent.right
            host: view
            side: "right"
            boxSize: view.boxSize
          }
        }

        // ---------- Strahl mit Tomate in der Mitte ----------
        Item {
          id: line
          width: parent.width
          height: Style.space(34)

          Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Style.space(2)
            radius: height / 2
            color: Qt.rgba(view.fg.r, view.fg.g, view.fg.b, 0.15)
          }

          Rectangle {
            id: fill
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * (view.pomo ? (view.pomo.done ? 1 : view.pomo.progress) : 0)
            height: Style.space(2)
            radius: height / 2
            color: view.phaseColor
            Behavior on width { NumberAnimation { duration: Style.duration(250); easing.type: Easing.OutCubic } }
          }

          Rectangle {
            visible: view.pomo && view.pomo.active
            x: fill.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(7)
            height: width
            radius: width / 2
            color: view.phaseColor
          }

          // Tomate (Hintergrund deckt den Strahl ab)
          Rectangle {
            id: tomatoSpot
            anchors.centerIn: parent
            width: Style.space(40)
            height: width
            radius: width / 2
            color: Commons.Color.popups.background

            TomatoIcon {
              anchors.centerIn: parent
              width: Style.space(28)
              height: width
              visible: !(view.pomo && view.pomo.done)
              opacity: view.pomo && view.pomo.paused ? 0.45 : 1
              idleColor: view.fg
              mode: !view.pomo ? 0 : (view.pomo.active && view.pomo.isWork ? 1 : (view.pomo.active ? 2 : 0))
            }

            SplatIcon {
              anchors.centerIn: parent
              width: Style.space(36)
              height: width
              visible: view.pomo ? view.pomo.done : false
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: view.info = "btn:tomato"
              onExited: if (view.info === "btn:tomato") view.info = ""
              onClicked: view.pomo.primary()
            }
          }
        }

        // ---------- unten: Status · Knöpfe ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(statusCol.implicitHeight, btnRow.implicitHeight, statusCol.restHeight)

          Column {
            id: statusCol
            // Höhe des normalen Status merken, damit Erklärungen nichts verschieben
            property real restHeight: 0
            onImplicitHeightChanged: if (shownInfo === "") restHeight = implicitHeight
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: btnRow.width + Style.space(10)
            anchors.rightMargin: btnRow.width + Style.space(10)
            spacing: Style.space(4)

            readonly property string shownInfo: view.customizing ? ""
              : (view.info !== "" ? view.info : (view.helpPinned ? "help" : ""))

            // Normal: Status + ? / Heute / Runde
            Row {
              visible: statusCol.shownInfo === ""
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(6)

              Text {
                width: Math.min(implicitWidth, statusCol.width - help.width - Style.space(6))
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                color: view.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                text: {
                  var p = view.pomo
                  if (!p) return ""
                  if (p.done) return p.tr.t(p.nextBreak === "long" ? "status.doneLong" : "status.doneShort")
                    .arg(p.nextBreak === "long" ? p.settings.longBreak : p.settings.shortBreak)
                  if (p.running) return p.tr.t("status.running").arg(p.fmtTime(p.st.endMs))
                  if (p.paused) return p.tr.t("status.paused")
                  if (p.isWork) return p.tr.t("status.idle")
                  return p.tr.t("status.idleBreak").arg(p.phaseName(p.phase))
                }
              }

              // ? – kurze Hilfe
              Rectangle {
                id: help
                width: Style.space(18)
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(view.fg.r, view.fg.g, view.fg.b, helpMa.containsMouse ? 0.7 : 0.3)
                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "?"
                  color: view.fg
                  opacity: 0.8
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
                MouseArea {
                  id: helpMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: view.info = "help"
                  onExited: if (view.info === "help") view.info = ""
                  onClicked: view.helpPinned = !view.helpPinned
                }
              }
            }

            Text {
              visible: statusCol.shownInfo === ""
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              color: view.fg
              opacity: 0.6
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              text: !view.pomo ? "" : view.t("today").arg(view.pomo.stats.today.done).arg(view.pomo.settings.dailyGoal)
                .arg(view.pomo.fmtDuration(view.pomo.stats.today.focusSec))
            }

            Row {
              visible: statusCol.shownInfo === ""
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(5)
              readonly property int inCycle: !view.pomo || view.pomo.st.cycle === 0 ? 0
                : (view.pomo.isWork && !view.pomo.done && view.pomo.st.cycle % view.pomo.settings.interval === 0
                   ? 0 : ((view.pomo.st.cycle - 1) % view.pomo.settings.interval) + 1)

              Repeater {
                model: view.pomo ? view.pomo.settings.interval : 0
                Rectangle {
                  readonly property bool filled: index < parent.inCycle
                  width: Style.space(8)
                  height: width
                  radius: width / 2
                  anchors.verticalCenter: parent.verticalCenter
                  color: filled ? view.red : "transparent"
                  border.width: 1
                  border.color: filled ? view.red : Qt.rgba(view.fg.r, view.fg.g, view.fg.b, 0.4)
                }
              }

              Text {
                textFormat: Text.PlainText
                leftPadding: Style.space(3)
                color: view.fg
                opacity: 0.6
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                text: view.pomo ? view.t("cycle").arg(view.pomo.tr.tn("sessions", view.pomo.settings.interval).arg(view.pomo.settings.interval)) : ""
              }
            }

            // Erklärung beim Drüberfahren
            InfoText {
              visible: statusCol.shownInfo !== ""
              width: parent.width
              host: view
              key: statusCol.shownInfo
            }
          }

          // ✎ Anpassen · ⚙ Einstellungen
          Row {
            id: btnRow
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Style.space(6)

            Button {
              bordered: true
              selected: view.customizing
              iconText: "󰏫"
              onClicked: view.pomo.customizing = !view.pomo.customizing
              onHovered: function(h) { view.info = h ? "ui:customize" : "" }
            }
            Button {
              bordered: true
              iconText: "󰒓"
              onClicked: view.openSettings("history")
              onHovered: function(h) { view.info = h ? "ui:settings" : "" }
            }
          }
        }
      }
    }

    // ---------- Baukasten (nur beim Anpassen) ----------
    Column {
      visible: view.customizing
      width: parent.width
      spacing: Style.space(8)

      PanelSeparator { width: parent.width }

      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: view.t("custom.box") + "  ·  " + view.t("custom.boxHint")
        color: view.fg
        opacity: 0.7
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Rectangle {
        width: parent.width
        implicitHeight: boxFlow.implicitHeight + Style.space(16)
        radius: Style.cornerRadius > 0 ? Style.space(8) : 0
        color: boxDrop.containsDrag ? Qt.rgba(view.fg.r, view.fg.g, view.fg.b, 0.08) : Qt.rgba(view.fg.r, view.fg.g, view.fg.b, 0.03)
        border.width: 1
        border.color: Qt.rgba(view.fg.r, view.fg.g, view.fg.b, boxDrop.containsDrag ? 0.5 : 0.12)

        Flow {
          id: boxFlow
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(8)

          Repeater {
            model: view.pomo ? Model.unusedTiles(view.pomo.settings.boxes || Model.DEFAULT_BOXES) : []
            Tile {
              host: view
              dropLayer: view.dragLayer
              tileId: modelData.id
              side: ""
              index: -1
              size: Style.space(40)
            }
          }

          Text {
            visible: view.pomo && Model.unusedTiles(view.pomo.settings.boxes || Model.DEFAULT_BOXES).length === 0
            textFormat: Text.PlainText
            text: view.t("custom.allUsed")
            color: view.fg
            opacity: 0.5
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        // Zurück in den Baukasten ziehen = entfernen
        DropArea {
          id: boxDrop
          anchors.fill: parent
          keys: ["pomo-tile"]
          onDropped: function(d) {
            var id = d.source.tileId
            Qt.callLater(function() { view.removeTile(id) })
          }
        }
      }

      // Erklärung beim Bearbeiten: ganz unten, damit nichts darüber verrutscht
      Rectangle {
        width: parent.width
        implicitHeight: editInfo.implicitHeight + Style.space(16)
        radius: Style.cornerRadius > 0 ? Style.space(8) : 0
        color: Qt.rgba(view.fg.r, view.fg.g, view.fg.b, 0.04)

        InfoText {
          id: editInfo
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(8)
          host: view
          key: view.info !== "" ? view.info : "help"
          align: Text.AlignLeft
        }
      }

      Row {
        spacing: Style.space(8)
        Button {
          bordered: true
          text: view.t("custom.reset")
          onClicked: view.saveBoxes(Model.copy(Model.DEFAULT_BOXES))
        }
        Button {
          bordered: true
          text: view.t("custom.done")
          onClicked: view.pomo.customizing = false
        }
      }
    }
  }

  // gezogene Kacheln hängen hier
  Item { id: dragLayerItem; anchors.fill: parent; z: 100 }
}
