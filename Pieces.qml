import QtQuick
import qs.Commons

// Tomatenstücke: fliegen beim Platzen aus der Mitte (origin) über die Karte
// und bleiben liegen, bis zurückgesetzt wird. Positionen hängen am seed,
// damit sie beim erneuten Öffnen gleich liegen.
Item {
  id: pieces
  property bool active: false
  property real originX: width / 2
  property real originY: height / 2
  property real seed: 1
  property real progress: 0

  function play() {
    if (!active) return
    fly.stop()
    progress = 0
    fly.start()
  }

  onActiveChanged: if (active) play(); else { fly.stop(); progress = 0 }

  NumberAnimation on progress {
    id: fly
    running: false
    from: 0
    to: 1
    duration: Style.duration(650)
    easing.type: Easing.OutCubic
  }

  // kleiner deterministischer Zufall
  function rand(i, k) {
    var x = Math.sin(seed * 0.0001 + i * 12.9898 + k * 78.233) * 43758.5453
    return x - Math.floor(x)
  }

  Repeater {
    model: 22
    Canvas {
      id: piece
      readonly property int kind: index < 9 ? 0 : index < 15 ? 1 : index < 19 ? 2 : 3   // Stück, Kern, Blatt, Tropfen
      readonly property real size: kind === 0 ? Style.space(10 + pieces.rand(index, 1) * 12)
        : kind === 1 ? Style.space(5) : kind === 2 ? Style.space(9) : Style.space(6 + pieces.rand(index, 2) * 6)
      readonly property real tx: pieces.rand(index, 3) * (pieces.width - size)
      readonly property real ty: pieces.rand(index, 4) * (pieces.height - size)
      readonly property real spin: (pieces.rand(index, 5) - 0.5) * 540

      visible: pieces.active
      width: size
      height: size
      x: pieces.originX - size / 2 + (tx - pieces.originX + size / 2) * pieces.progress
      y: pieces.originY - size / 2 + (ty - pieces.originY + size / 2) * pieces.progress
      rotation: spin * pieces.progress
      scale: 0.4 + 0.6 * pieces.progress
      opacity: kind === 1 ? 0.9 : 0.75

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var s = width, c = s / 2
        if (kind === 0) {
          // unregelmäßiges Fruchtstück
          ctx.fillStyle = "#e5484d"
          ctx.beginPath()
          for (var i = 0; i <= 7; i++) {
            var a = i / 7 * Math.PI * 2
            var r = s * (0.32 + pieces.rand(index, 10 + i) * 0.18)
            if (i === 0) ctx.moveTo(c + Math.cos(a) * r, c + Math.sin(a) * r)
            else ctx.lineTo(c + Math.cos(a) * r, c + Math.sin(a) * r)
          }
          ctx.closePath()
          ctx.fill()
          ctx.fillStyle = "#ff8a7a"
          ctx.beginPath()
          ctx.arc(c, c, s * 0.16, 0, Math.PI * 2)
          ctx.fill()
        } else if (kind === 1) {
          ctx.fillStyle = "#ffe7a3"
          ctx.beginPath()
          ctx.ellipse(s * 0.2, s * 0.3, s * 0.6, s * 0.4)
          ctx.fill()
        } else if (kind === 2) {
          ctx.fillStyle = "#46a758"
          ctx.beginPath()
          ctx.moveTo(c, 0)
          ctx.quadraticCurveTo(s, c, c, s)
          ctx.quadraticCurveTo(0, c, c, 0)
          ctx.fill()
        } else {
          ctx.fillStyle = "#e5484d"
          ctx.beginPath()
          ctx.arc(c, c, s * 0.45, 0, Math.PI * 2)
          ctx.fill()
        }
      }
      Component.onCompleted: requestPaint()
    }
  }
}
