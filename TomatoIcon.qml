import QtQuick
import qs.Commons

// Die Tomate. mode: 0 Ruhe (Systemfarbe, Blätter halbtransparent),
// 1 Fokus (rot/grün), 2 Pause (grün/dunkelgrün)
Canvas {
  id: tomato
  property int mode: 0
  property color idleColor: "white"
  property color red: "#e5484d"
  property color leafGreen: "#46a758"
  property color breakGreen: "#5bb974"
  property color body: mode === 1 ? red : mode === 2 ? breakGreen : idleColor
  onBodyChanged: requestPaint()
  onModeChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  Behavior on body { ColorAnimation { duration: Style.duration(200) } }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.scale(width / 24, height / 24)
    var BODY = "M12 7.4 C9.4 5.7 3.9 6 2.7 11.4 C1.7 16.6 5.8 21.7 12 21.7 C18.2 21.7 22.3 16.6 21.3 11.4 C20.1 6 14.6 5.7 12 7.4 Z"
    var LEAVES = "M12 5.6 L9.3 4.6 Q7 4.3 5.2 5.8 Q7.9 6.1 9.1 7.3 Q7.4 8.6 7 11.3 Q9.6 9.6 12 9.3 Q14.4 9.6 17 11.3 Q16.6 8.6 14.9 7.3 Q16.1 6.1 18.8 5.8 Q17 4.3 14.7 4.6 Z "
               + "M11 6 Q11 3.5 12.6 1.9 L14.2 2.9 Q13 4.2 13 6 Z"
    function fillPath(d, color, alpha) {
      ctx.globalAlpha = alpha
      ctx.fillStyle = color
      ctx.beginPath()
      ctx.path = d
      ctx.fill()
      ctx.globalAlpha = 1
    }
    fillPath(BODY, body, 1)
    ctx.globalCompositeOperation = "destination-out"
    fillPath(LEAVES, "black", 1)
    ctx.globalCompositeOperation = "source-over"
    if (mode === 1) fillPath(LEAVES, leafGreen, 1)
    else if (mode === 2) fillPath(LEAVES, "#2f7d45", 1)
    else fillPath(LEAVES, body, 0.5)
  }
}
