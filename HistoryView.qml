import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Verlauf: Überblick, Monatskalender, Tagesdetails, Löschen.
Column {
  id: view
  property var pomo: null
  spacing: Style.space(10)

  readonly property color fg: Commons.Color.foreground
  readonly property color red: "#e5484d"
  readonly property var loc: pomo ? pomo.loc : Qt.locale(Commons.I18n.formatLocale)

  property int year: new Date().getFullYear()
  property int month: new Date().getMonth()
  property string selectedKey: Model.dayKey(Date.now())
  property string armed: ""   // Löschknopf, der auf Bestätigung wartet

  readonly property var cells: pomo ? Model.monthGrid(pomo.history, year, month, pomo.now) : []
  readonly property var dayEntries: pomo ? Model.entriesForDay(pomo.history, selectedKey) : []

  function t(key) { return pomo ? pomo.tr.t(key) : "" }

  function shiftMonth(delta) {
    var d = new Date(year, month + delta, 1)
    year = d.getFullYear()
    month = d.getMonth()
  }

  // Zweistufiges Löschen: erster Klick schärft, zweiter löscht.
  function confirm(id, action) {
    if (armed === id) { armed = ""; action() }
    else { armed = id; disarm.restart() }
  }

  Timer { id: disarm; interval: 3000; onTriggered: view.armed = "" }

  function deleteEntry(id) {
    pomo.writeHistory(pomo.history.filter(function(e) { return e.id !== id }))
  }

  function deleteDay(key) {
    pomo.writeHistory(pomo.history.filter(function(e) { return Model.dayKey(e.start) !== key }))
  }

  function deleteAll() { pomo.writeHistory([]) }

  // ---------- Überblick ----------
  Grid {
    width: parent.width
    columns: 4
    columnSpacing: Style.space(8)
    rowSpacing: Style.space(4)

    Repeater {
      model: [
        { k: "hist.today", v: view.pomo ? view.pomo.stats.today : null },
        { k: "hist.week", v: view.pomo ? view.pomo.stats.week : null },
        { k: "hist.month", v: view.pomo ? view.pomo.stats.month : null },
        { k: "hist.total", v: view.pomo ? view.pomo.stats.total : null }
      ]
      Column {
        width: (view.width - Style.space(24)) / 4
        spacing: Style.space(2)
        Text {
          textFormat: Text.PlainText
          text: view.t(modelData.k)
          color: view.fg; opacity: 0.6
          font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
        Text {
          textFormat: Text.PlainText
          text: modelData.v ? String(modelData.v.done) : "0"
          color: view.red
          font.family: Style.font.family; font.pixelSize: Style.font.body * 1.4; font.bold: true
        }
        Text {
          textFormat: Text.PlainText
          text: modelData.v ? view.pomo.fmtDuration(modelData.v.focusSec) : ""
          color: view.fg; opacity: 0.8
          font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
      }
    }
  }

  Text {
    visible: view.pomo && view.pomo.stats.streak > 0
    textFormat: Text.PlainText
    text: view.pomo ? "🔥 " + view.pomo.tr.tn("hist.streak", view.pomo.stats.streak).arg(view.pomo.stats.streak) : ""
    color: view.fg
    font.family: Style.font.family; font.pixelSize: Style.font.caption
  }

  PanelSeparator { width: parent.width }

  // ---------- Monatskopf ----------
  Item {
    width: parent.width
    implicitHeight: prevBtn.implicitHeight

    Button { id: prevBtn; anchors.left: parent.left; text: "‹"; onClicked: view.shiftMonth(-1) }
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: view.loc.toString(new Date(view.year, view.month, 1), "MMMM yyyy")
      color: view.fg
      font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true
    }
    Button { anchors.right: parent.right; text: "›"; onClicked: view.shiftMonth(1) }
  }

  // ---------- Kalender ----------
  Grid {
    id: cal
    width: parent.width
    columns: 7
    readonly property real cellW: width / 7
    readonly property real cellH: Style.space(34)

    Repeater {
      model: 7
      Text {
        width: cal.cellW
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        // 2026-11-23 war ein Montag
        text: view.loc.toString(new Date(2026, 10, 23 + index), "ddd")
        color: view.fg; opacity: 0.5
        font.family: Style.font.family; font.pixelSize: Style.font.caption
        bottomPadding: Style.space(4)
      }
    }

    Repeater {
      model: view.cells
      Item {
        width: cal.cellW
        height: cal.cellH
        opacity: modelData.inMonth ? 1 : 0.35

        Rectangle {
          anchors.fill: parent
          anchors.margins: Style.space(2)
          radius: Style.cornerRadius > 0 ? Style.space(6) : 0
          color: modelData.done > 0 ? Qt.rgba(0.9, 0.28, 0.3, 0.18 + 0.62 * modelData.level) : "transparent"
          border.width: modelData.key === view.selectedKey ? 2 : (modelData.isToday ? 1 : 0)
          border.color: modelData.key === view.selectedKey ? Commons.Color.accent : view.fg
        }

        Column {
          anchors.centerIn: parent
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: String(modelData.day)
            color: view.fg
            font.family: Style.font.family; font.pixelSize: Style.font.caption
            font.bold: modelData.isToday
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: modelData.done > 0
            textFormat: Text.PlainText
            text: "🍅" + modelData.done
            color: view.fg
            font.family: Style.font.family; font.pixelSize: Style.font.caption * 0.8
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: view.selectedKey = modelData.key
        }
      }
    }
  }

  PanelSeparator { width: parent.width }

  // ---------- Tagesdetail ----------
  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    text: {
      var done = 0, sec = 0
      for (var i = 0; i < view.dayEntries.length; i++) {
        if (view.dayEntries[i].status === "done") done++
        sec += view.dayEntries[i].focusSec
      }
      var date = view.loc.toString(Model.keyToDate(view.selectedKey), view.t("fmt.dayTitle"))
      return view.pomo ? date + "  ·  " + view.pomo.tr.tn("sessions", done).arg(done) + "  ·  " + view.pomo.fmtDuration(sec) : ""
    }
    color: view.fg
    font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true
  }

  Text {
    visible: view.dayEntries.length === 0
    textFormat: Text.PlainText
    text: view.t("hist.empty")
    color: view.fg; opacity: 0.6
    font.family: Style.font.family; font.pixelSize: Style.font.caption
  }

  Flickable {
    width: parent.width
    height: Math.min(contentHeight, Style.space(180))
    contentHeight: list.implicitHeight
    clip: true
    visible: view.dayEntries.length > 0
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: list
      width: parent.width
      spacing: Style.space(2)

      Repeater {
        model: view.dayEntries
        Item {
          width: list.width
          implicitHeight: Math.max(row.implicitHeight, del.implicitHeight)

          Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            Text {
              textFormat: Text.PlainText
              text: modelData.status === "done" ? "🍅" : "✗"
              color: view.red
              font.family: Style.font.family; font.pixelSize: Style.font.body
            }
            Text {
              textFormat: Text.PlainText
              text: view.pomo.fmtTime(modelData.start) + " – " + view.pomo.fmtTime(modelData.end)
              color: view.fg
              font.family: Style.font.family; font.pixelSize: Style.font.body
            }
            Text {
              textFormat: Text.PlainText
              text: modelData.status === "done" ? view.pomo.fmtDuration(modelData.focusSec)
                : view.t("hist.abortedAfter").arg(view.pomo.fmtDuration(modelData.focusSec))
              color: view.fg
              opacity: modelData.status === "done" ? 0.8 : 0.55
              font.family: Style.font.family; font.pixelSize: Style.font.body
            }
          }

          Button {
            id: del
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: view.armed === "e" + modelData.id ? view.t("hist.confirmShort") : "✕"
            foreground: view.armed === "e" + modelData.id ? view.red : Commons.Color.foreground
            tooltipText: view.t("hist.deleteEntry")
            onClicked: view.confirm("e" + modelData.id, function() { view.deleteEntry(modelData.id) })
          }
        }
      }
    }
  }

  Row {
    spacing: Style.space(8)

    Button {
      bordered: true
      visible: view.dayEntries.length > 0
      text: view.armed === "day" ? view.t("hist.confirm") : view.t("hist.deleteDay")
      foreground: view.armed === "day" ? view.red : Commons.Color.foreground
      onClicked: view.confirm("day", function() { view.deleteDay(view.selectedKey) })
    }

    Button {
      bordered: true
      visible: view.pomo && view.pomo.history.length > 0
      text: view.armed === "all" ? view.t("hist.confirm") : view.t("hist.deleteAll")
      foreground: view.armed === "all" ? view.red : Commons.Color.foreground
      onClicked: view.confirm("all", function() { view.deleteAll() })
    }
  }
}
