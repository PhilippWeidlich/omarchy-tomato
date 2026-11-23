import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Zeile "Beschriftung   −  25 min  +"; Mausrad verstellt ebenfalls.
Item {
  id: stepper
  property var host: null
  property string label: ""
  property string key: ""
  property int from: 1
  property int to: 60
  property string unit: "min"
  readonly property int value: host && host.s[key] !== undefined ? host.s[key] : 0
  readonly property color fg: Commons.Color.foreground

  implicitHeight: Math.max(minus.implicitHeight, labelText.implicitHeight)

  function change(delta) {
    var v = Math.max(from, Math.min(to, value + delta))
    if (v !== value) host.set(key, v)
  }

  Text {
    id: labelText
    anchors.left: parent.left
    anchors.right: controls.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    text: stepper.label
    color: stepper.fg
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Row {
    id: controls
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(6)

    Button { id: minus; bordered: true; text: "−"; onClicked: stepper.change(-1) }

    Text {
      width: Style.space(84)
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignHCenter
      textFormat: Text.PlainText
      text: !stepper.host ? "" : stepper.unit === "min" ? stepper.host.t("set.minutes").arg(stepper.value)
        : stepper.host.pomo.tr.tn("sessions", stepper.value).arg(stepper.value)
      color: stepper.fg
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      MouseArea {
        anchors.fill: parent
        onWheel: function(w) { stepper.change(w.angleDelta.y > 0 ? 1 : -1) }
      }
    }

    Button { bordered: true; text: "+"; onClicked: stepper.change(1) }
  }
}
