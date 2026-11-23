import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Zweite Seite der Karte: ‹ zurück · Verlauf · Einstellungen
Column {
  id: page
  property var pomo: null
  spacing: Style.space(12)

  Item {
    width: parent.width
    implicitHeight: Math.max(back.implicitHeight, tabs.implicitHeight)

    Button {
      id: back
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      bordered: true
      iconText: "󰁍"
      text: page.pomo ? page.pomo.tr.t("nav.back") : ""
      onClicked: page.pomo.page = "main"
    }

    ButtonGroup {
      id: tabs
      anchors.left: back.right
      anchors.leftMargin: Style.space(8)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      options: page.pomo ? [
        { value: "history", label: page.pomo.tr.t("tab.history") },
        { value: "settings", label: page.pomo.tr.t("tab.settings") }
      ] : []
      value: page.pomo ? page.pomo.tab : "history"
      onChanged: function(v) { page.pomo.tab = v }
    }
  }

  HistoryView {
    width: parent.width
    pomo: page.pomo
    visible: page.pomo && page.pomo.tab !== "settings"
  }

  SettingsView {
    width: parent.width
    pomo: page.pomo
    visible: page.pomo && page.pomo.tab === "settings"
  }
}
