import QtQuick

// Geplatzte Tomate (Fleck mit Spritzern, Fruchtfleisch, Kernen, Strunk).
Canvas {
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.scale(width / 24, height / 24)
      var SPLAT = "M4.6 11.8 Q6.2 9.4 9 9.6 Q11.2 8.4 13.6 9.2 Q16.6 8.6 18.4 10.6 L22.4 9.2 L19.6 12 Q21.2 14 19.8 16.2 L22.8 18.4 L18.6 17.6 Q16.4 20.2 13 19.6 L12.2 22.6 L11 19.6 Q7.4 20.2 5.4 18 L1.6 19.2 L4.2 16.4 Q2.8 14.4 3.6 12.6 L0.8 10.2 Z"
      var FLESH = "M7 13 L9 12.4 L9.6 10.8 L11.4 12 L13.6 10.6 L14.2 12.4 L16.8 12.2 L15.6 14.2 L17 16.2 L14.4 16 L13.2 17.8 L11.6 16.4 L9.2 17.6 L9.2 15.6 L6.8 15.4 L8.2 14.2 Z"
      var CALYX = "M12 6.4 L9.8 5.6 Q8 5.3 6.5 6.6 Q8.6 6.8 9.6 7.8 Q8.3 8.9 8 10.8 Q10.1 9.5 12 9.3 Q13.9 9.5 16 10.8 Q15.7 8.9 14.4 7.8 Q15.4 6.8 17.5 6.6 Q16 5.3 14.2 5.6 Z M11.1 6.6 Q11 4.6 12.2 3.2 L13.4 4 Q12.6 5.2 12.7 6.6 Z"
      function fillPath(d, color) {
        ctx.fillStyle = color
        ctx.beginPath()
        ctx.path = d
        ctx.fill()
      }
      function dots(list, color) {
        ctx.fillStyle = color
        for (var i = 0; i < list.length; i++) {
          ctx.beginPath()
          ctx.arc(list[i][0], list[i][1], list[i][2], 0, 2 * Math.PI)
          ctx.fill()
        }
      }
      ctx.lineJoin = "round"
      ctx.lineWidth = 0.6
      ctx.strokeStyle = "#e5484d"
      fillPath(SPLAT, "#e5484d")
      ctx.stroke()
      dots([[2.8, 6.6, 1.2], [21.6, 5.8, 1.0], [17.3, 22, 0.9], [6.2, 22, 0.8]], "#e5484d")
      fillPath(FLESH, "#ff8a7a")
      dots([[10.75, 13.4, 0.55], [13.55, 13, 0.55], [12.15, 15.2, 0.55], [14.9, 15, 0.5], [9.5, 15, 0.5]], "#ffe7a3")
      ctx.save()
      ctx.translate(12, 8)
      ctx.rotate(-18 * Math.PI / 180)
      ctx.translate(-12, -8)
      fillPath(CALYX, "#46a758")
      ctx.restore()
    }
}
