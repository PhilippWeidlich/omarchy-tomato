import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Pomodoro-Tomate für die Leiste.
//  Ruhe: Tomate in Systemfarbe · Fokus: rot · Pause: grün · angehalten: blass
//  Fokus fertig: Tomate platzt (Fleck bleibt bis zum Klick bzw. Auto-Pause)
//  Linksklick: starten / Karte · Mittelklick: anhalten/fortsetzen · Rechtsklick: Karte
// Dateien in ~/.local/state/tomato/: state.json, settings.json, history.json
BarWidget {
  id: root
  moduleName: "philippweidlich.tomato"

  Translator { id: strings; directory: Qt.resolvedUrl("i18n"); choice: root.settings && root.settings.language ? root.settings.language : "auto" }
  readonly property var tr: strings
  // Datumsformat folgt der Plugin-Sprache (bei "auto" der Omarchy-Sprache)
  readonly property var loc: Qt.locale(strings.choice === "de" ? "de_DE" : strings.choice === "en" ? "en_US" : Commons.I18n.formatLocale)

  readonly property color tomatoRed: "#e5484d"
  readonly property color leafGreen: "#46a758"
  readonly property color breakGreen: "#5bb974"
  readonly property color idleColor: root.bar ? root.bar.barForeground : Commons.Color.foreground
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/tomato"

  // ---------- Daten ----------
  property var settings: Model.sanitizeSettings({})
  property var st: Model.emptyState()
  property var history: []
  property bool stateReady: false
  property bool settingsReady: false
  readonly property bool ready: stateReady && settingsReady

  property real now: Date.now()

  readonly property string phase: st.phase
  readonly property string status: st.status
  readonly property bool running: status === "running"
  readonly property bool paused: status === "paused"
  readonly property bool done: status === "done"
  readonly property bool idle: status === "idle"
  readonly property bool active: running || paused
  readonly property bool isWork: phase === "work"

  readonly property real plannedMs: active ? st.plannedMs : Model.phaseMinutes(settings, phase) * 60000
  readonly property real remainingMs: running ? Math.max(0, st.endMs - now)
    : paused ? st.remainingMs : (done ? 0 : plannedMs)
  readonly property real progress: plannedMs > 0 ? Math.max(0, Math.min(1, 1 - remainingMs / plannedMs)) : 0
  readonly property string nextBreak: nextBreakFor(st.cycle)
  readonly property var stats: Model.summary(history, now)

  function nextBreakFor(cycle) {
    return cycle > 0 && cycle % settings.interval === 0 ? "long" : "short"
  }

  function phaseName(p) { return tr.t("phase." + p) }
  function phaseColor(p) { return p === "work" ? tomatoRed : breakGreen }

  function fmtDuration(sec) {
    var m = Math.round(sec / 60)
    if (m >= 60) return tr.t("dur.hm").arg(Math.floor(m / 60)).arg(m % 60)
    return tr.t("dur.m").arg(m)
  }

  function fmtTime(ms) {
    return root.loc.toString(new Date(ms), "HH:mm")
  }

  // ---------- Dateien ----------
  function writeState(s) {
    st = s
    stateFile.setText(JSON.stringify(s) + "\n")
  }

  function writeSettings(s) {
    settings = Model.sanitizeSettings(s)
    settingsFile.setText(JSON.stringify(settings, null, 2) + "\n")
  }

  function setSetting(key, value) {
    var next = Model.copy(settings)
    next[key] = value
    writeSettings(next)
  }

  function writeHistory(h) {
    history = h
    historyFile.setText(JSON.stringify({ version: 1, entries: h }) + "\n")
  }

  function parse(text) {
    try { return JSON.parse(text || "null") } catch (e) { return null }
  }

  FileView {
    id: stateFile
    path: root.stateDir + "/state.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { root.st = Model.sanitizeState(root.parse(text())); root.stateReady = true; root.now = Date.now() }
    onLoadFailed: { root.st = Model.emptyState(); root.stateReady = true }
  }

  FileView {
    id: settingsFile
    path: root.stateDir + "/settings.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { root.settings = Model.sanitizeSettings(root.parse(text())); root.settingsReady = true }
    onLoadFailed: { root.settings = Model.sanitizeSettings({}); root.settingsReady = true }
  }

  FileView {
    id: historyFile
    path: root.stateDir + "/history.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.history = Model.sanitizeHistory(root.parse(text()))
    onLoadFailed: root.history = []
  }

  // ---------- Aktionen ----------
  function startPhase(p) {
    var t = Date.now()
    var s = Model.copy(st)
    if (p === "work") {
      var today = Model.dayKey(t)
      if (s.cycleDay !== today) { s.cycle = 0; s.cycleDay = today }
    }
    var planned = Model.phaseMinutes(settings, p) * 60000
    s.phase = p
    s.status = "running"
    s.startMs = t
    s.plannedMs = planned
    s.endMs = t + planned
    s.remainingMs = 0
    s.pausedMs = 0
    s.pauseAt = 0
    now = t
    writeState(s)
  }

  function pause() {
    if (!running) return
    var t = Date.now()
    var s = Model.copy(st)
    s.status = "paused"
    s.remainingMs = Math.max(1000, s.endMs - t)
    s.pauseAt = t
    writeState(s)
  }

  function resume() {
    if (!paused) return
    var t = Date.now()
    var s = Model.copy(st)
    s.status = "running"
    s.endMs = t + s.remainingMs
    s.pausedMs += Math.max(0, t - s.pauseAt)
    s.pauseAt = 0
    s.remainingMs = 0
    now = t
    writeState(s)
  }

  // Linksklick / Hauptknopf
  function primary() {
    if (idle) startPhase(phase)
    else if (running) pause()
    else if (paused) resume()
    else if (done) startPhase(nextBreak)
  }

  function focusSecSoFar(s, t) {
    var stop = s.status === "paused" ? s.pauseAt : t
    return Math.max(0, Math.round((stop - s.startMs - s.pausedMs) / 1000))
  }

  // Abgebrochene Fokus-Session (ab 1 Minute) im Verlauf festhalten
  function logAborted(s, t) {
    if (s.phase !== "work" || (s.status !== "running" && s.status !== "paused")) return
    var sec = focusSecSoFar(s, t)
    if (sec < 60) return
    appendHistory({ id: String(s.startMs), start: s.startMs, end: t, focusSec: sec,
                    plannedSec: Math.round(s.plannedMs / 1000), status: "aborted" })
  }

  function appendHistory(entry) {
    var h = history.slice()
    for (var i = 0; i < h.length; i++) if (h[i].id === entry.id) return
    h.push(entry)
    writeHistory(Model.sanitizeHistory(h))
  }

  function idleAt(s, p) {
    s.phase = p
    s.status = "idle"
    s.startMs = 0; s.endMs = 0; s.plannedMs = 0; s.remainingMs = 0; s.pausedMs = 0; s.pauseAt = 0
    return s
  }

  function skip() {
    var t = Date.now()
    var s = Model.copy(st)
    if (done) { writeState(idleAt(s, "work")); return }
    if (s.phase === "work") {
      var wasActive = active
      logAborted(s, t)
      var brk = nextBreakFor(s.cycle)
      if (wasActive && settings.autoBreak) { st = idleAt(s, brk); startPhase(brk) }
      else writeState(idleAt(s, brk))
    } else {
      var wasRunning = active
      if (wasRunning && settings.autoWork) { st = idleAt(s, "work"); startPhase("work") }
      else writeState(idleAt(s, "work"))
    }
  }

  function reset() {
    var t = Date.now()
    var s = Model.copy(st)
    if (idle && s.phase === "work") s.cycle = 0   // in Ruhe: Runde neu beginnen
    else logAborted(s, t)
    writeState(idleAt(s, "work"))
  }

  function dismissOverlay() {
    var s = Model.copy(st)
    s.overlayDismissed = s.startMs
    writeState(s)
  }

  // ---------- Ablauf (nur der Leader schreibt) ----------
  function playSound(name) {
    Quickshell.execDetached(["pw-play", Model.soundPath(name)])
  }

  function notifyUser(title, body) {
    if (settings.notify)
      Quickshell.execDetached(["omarchy-notification-send", "-u", "normal", "-g", "󰔛", title, body])
    if (settings.sound) soundTimer.restart()
  }

  Timer {
    id: soundTimer
    interval: 700
    onTriggered: root.playSound(root.settings.soundName)
  }

  function finishIfDue() {
    if (!ready || !running || now < st.endMs) return
    if (!Model.isLeader(root) || !Model.claimEnd(st.endMs)) return
    var s = Model.copy(st)
    if (s.phase === "work") {
      appendHistory({ id: String(s.startMs), start: s.startMs, end: s.endMs,
                      focusSec: Math.round(s.plannedMs / 1000), plannedSec: Math.round(s.plannedMs / 1000), status: "done" })
      s.cycle += 1
      s.cycleDay = Model.dayKey(s.startMs)
      s.status = "done"
      writeState(s)
      var brk = nextBreakFor(s.cycle)
      notifyUser(tr.t("notify.workTitle"),
        brk === "long" ? tr.t("notify.workLong").arg(settings.longBreak).arg(s.cycle)
                       : tr.t("notify.workShort").arg(settings.shortBreak))
      if (settings.autoBreak) autoBreakTimer.restart()
    } else {
      notifyUser(tr.t("notify.breakTitle"), tr.t("notify.breakBody"))
      if (settings.autoWork) { st = idleAt(s, "work"); startPhase("work") }
      else writeState(idleAt(s, "work"))
    }
  }

  Timer {
    id: autoBreakTimer
    interval: 3000
    onTriggered: if (root.done && Model.isLeader(root)) root.startPhase(root.nextBreak)
  }

  Timer {
    interval: root.running ? 1000 : 30000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      root.now = Date.now()
      root.finishIfDue()
    }
  }

  // ---------- Fokus-Modus: "Nicht stören" während Fokus ----------
  // Über den öffentlichen Befehl `omarchy-shell notifications …` (Widgets haben
  // keinen direkten Zugriff auf den Dienst). Die Tomate schaltet nur ein, wenn es
  // aus war, und schaltet nur dann am Ende wieder aus.
  readonly property bool dndWanted: ready && settings.focusDnd && isWork && active
  property real dndProbeFor: 0

  function setDnd(on) {
    Quickshell.execDetached(["omarchy-shell", "notifications", "setDnd", on ? "on" : "off"])
    refreshTimer.restart()
  }

  Timer { id: refreshTimer; interval: 400; onTriggered: root.refreshIndicators() }

  Process {
    id: dndProbe
    command: ["omarchy-shell", "notifications", "isDnd"]
    stdout: SplitParser {
      onRead: function(line) {
        var session = root.dndProbeFor
        root.dndProbeFor = 0
        if (!session || !root.dndWanted || root.st.startMs !== session) return
        var s = Model.copy(root.st)
        s.dndSession = session
        if (String(line).trim() === "off") {
          root.setDnd(true)
          s.dndOwned = true
        }
        root.writeState(s)
      }
    }
  }

  function syncDnd() {
    if (!ready || !Model.isLeader(root)) return
    if (dndWanted && st.dndSession !== st.startMs) {
      if (dndProbe.running || dndProbeFor === st.startMs) return
      dndProbeFor = st.startMs
      dndProbe.running = true
    } else if (!dndWanted && st.dndOwned) {
      if (settings.replayMissed) replayMissed(st.dndSession)
      var s = Model.copy(st)
      s.dndOwned = false
      setDnd(false)
      writeState(s)
    }
  }

  function refreshIndicators() {
    Quickshell.execDetached(["omarchy-shell", "-q", "omarchy.indicators", "refresh"])
  }

  onDndWantedChanged: Qt.callLater(syncDnd)
  onStChanged: Qt.callLater(syncDnd)
  onReadyChanged: { Qt.callLater(syncDnd); Qt.callLater(syncMute) }

  Component.onDestruction: Model.unregister(root)

  // ---------- Verpasstes nachholen ----------
  property real replaySince: 0

  function replayMissed(since) {
    if (!since) return
    replaySince = since
    missedTimer.restart()   // kurz warten, bis Omarchy den Verlauf geschrieben hat
  }

  Timer { id: missedTimer; interval: 1200; onTriggered: missedFile.reload() }

  FileView {
    id: missedFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/history.json"
    printErrors: false
    onLoaded: {
      if (root.replaySince <= 0) return
      var since = root.replaySince / 1000
      root.replaySince = 0
      var rows = root.parse(text())
      if (!Array.isArray(rows)) return
      var missed = rows.filter(function(r) {
        return r && r.closed_reason === "silenced" && Number(r.ts) >= since
      })
      if (missed.length === 0) return
      function clean(v, n) {
        var t = String(v || "").replace(/[<>&]/g, "").replace(/\s+/g, " ").trim()
        return t.length > n ? t.slice(0, n - 1) + "…" : t
      }
      var lines = []
      for (var i = Math.max(0, missed.length - 5); i < missed.length; i++)
        lines.push("• " + clean(missed[i].app, 24) + ": " + clean(missed[i].summary, 60))
      Quickshell.execDetached(["omarchy-notification-send", "-u", "normal", "-g", "󰋚",
        root.tr.tn("missed.title", missed.length).arg(missed.length), lines.join("\n")])
    }
  }

  // ---------- Andere Töne stumm (nur was die Tomate selbst stumm geschaltet hat, wird wieder laut) ----------
  readonly property bool muteWanted: ready && settings.muteAudio && isWork && active
  readonly property string muteFlag: stateDir + "/muted-by-tomato"

  function syncMute() {
    if (!ready || !Model.isLeader(root)) return
    if (muteWanted && st.muteSession !== st.startMs) {
      Quickshell.execDetached(["bash", "-c",
        'f="$1"; wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED || { wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 && touch "$f"; }',
        "mute", muteFlag])
      var s = Model.copy(st)
      s.muteSession = st.startMs
      writeState(s)
    } else if (!muteWanted) {
      Quickshell.execDetached(["bash", "-c",
        'f="$1"; [ -f "$f" ] && { wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; rm -f "$f"; } || true',
        "unmute", muteFlag])
    }
  }

  onMuteWantedChanged: Qt.callLater(syncMute)

  // ---------- Wach bleiben ----------
  IdleInhibitor {
    window: root.QsWindow.window
    enabled: root.ready && root.settings.stayAwake && root.isWork && root.active
  }

  Component.onCompleted: Model.register(root)

  // ---------- Tastenkürzel / Befehle ----------
  // omarchy-shell philippweidlich.tomato toggle | skip | reset
  ShellIpc {
    target: "philippweidlich.tomato"
    function toggle(): void { root.primary() }
    function skip(): void { root.skip() }
    function reset(): void { root.reset() }
    // Karte auf dem Monitor mit Fokus öffnen: open | open customize | open history | open settings
    function open(view: string): void { root.openOnFocusedScreen(view) }
    function close(): void { for (var i = 0; i < Model.instances.length; i++) Model.instances[i].close() }
  }

  function showCard(view) {
    scriptOpen = true
    customizing = view === "customize"
    if (view === "history" || view === "settings") { tab = view; page = "settings" }
    else page = "main"
    scriptOpen = true
  }

  function openOnFocusedScreen(view) {
    var mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    var target = null
    for (var i = 0; i < Model.instances.length; i++) {
      var w = Model.instances[i].QsWindow.window
      if (w && w.screen && w.screen.name === mon) target = Model.instances[i]
    }
    if (!target) target = Model.instances.length ? Model.instances[0] : root
    for (var j = 0; j < Model.instances.length; j++) if (Model.instances[j] !== target) Model.instances[j].close()
    target.showCard(String(view || "main"))
  }

  // ---------- Vollbild-Pause ----------
  BreakOverlay {
    pomo: root
    screen: root.QsWindow.window ? root.QsWindow.window.screen : null
    shown: root.ready && root.settings.fullscreenBreak && !root.isWork && root.active
      && root.st.overlayDismissed !== root.st.startMs
  }

  // ---------- Platzen ----------
  property bool wasDone: false
  onCustomizingChanged: if (customizing && !scriptOpen) pinned = true
  onPageChanged: if (page === "settings" && !scriptOpen) pinned = true

  onDoneChanged: {
    if (done && ready && !wasDone) burst.restart()
    if (!done) { burst.stop(); tomato.scale = 1; tomato.opacity = Qt.binding(function() { return root.paused ? 0.45 : 1 }); splat.scale = 1; splat.opacity = 1 }
    wasDone = done
  }
  onStateReadyChanged: wasDone = done

  // ---------- Karte ----------
  property bool pinned: false
  property bool hoverOpen: false
  property bool widgetHovered: false
  property string tab: "history"
  property string page: "main"
  property bool customizing: false
  property bool scriptOpen: false   // per Befehl geöffnet (ohne Fokus-Griff)

  function close() { pinned = false; hoverOpen = false; scriptOpen = false; customizing = false; page = "main" }

  Timer {
    id: hoverCloseTimer
    interval: 300
    onTriggered: {
      if (root.widgetHovered || popup.containsMouse) return
      root.hoverOpen = false
    }
  }

  Connections {
    target: popup
    function onContainsMouseChanged() { if (!popup.containsMouse) hoverCloseTimer.restart() }
  }

  // ---------- Leisten-Symbol ----------
  implicitWidth: Style.bar.statusSlot
  implicitHeight: barSize

  readonly property real iconSize: Style.bar.iconSize * 1.2

  Item {
    id: iconBox
    width: root.iconSize
    height: root.iconSize
    anchors.centerIn: parent
    scale: mouse.pressed ? 0.9 : 1
    Behavior on scale { NumberAnimation { duration: Style.duration(160); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }

    TomatoIcon {
      id: tomato
      anchors.fill: parent
      visible: !root.done || burst.running
      opacity: root.paused ? 0.45 : 1
      idleColor: root.idleColor
      mode: root.done || (root.active && root.isWork) ? 1 : (root.active ? 2 : 0)
    }

    SplatIcon {
      id: splat
      anchors.centerIn: parent
      width: parent.width * 1.2
      height: parent.height * 1.2
      visible: root.done
    }

    SequentialAnimation {
      id: burst
      NumberAnimation { target: tomato; property: "scale"; from: 1; to: 1.25; duration: Style.duration(140); easing.type: Easing.OutCubic }
      ParallelAnimation {
        NumberAnimation { target: tomato; property: "scale"; to: 1.6; duration: Style.duration(120); easing.type: Easing.OutCubic }
        NumberAnimation { target: tomato; property: "opacity"; from: 1; to: 0; duration: Style.duration(120) }
        NumberAnimation { target: splat; property: "scale"; from: 0.4; to: 1; duration: Style.duration(220); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
        NumberAnimation { target: splat; property: "opacity"; from: 0; to: 1; duration: Style.duration(140) }
      }
      ScriptAction { script: { tomato.scale = 1; tomato.opacity = Qt.binding(function() { return root.paused ? 0.45 : 1 }) } }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onEntered: { root.widgetHovered = true; root.hoverOpen = true }
    onExited: { root.widgetHovered = false; hoverCloseTimer.restart() }

    onClicked: function(m) {
      if (m.button === Qt.RightButton) { root.pinned = !root.pinned; return }
      if (m.button === Qt.MiddleButton) { if (root.active) root.primary(); return }
      if (root.idle || root.done) { root.primary(); return }
      root.pinned = !root.pinned
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.pinned || root.hoverOpen || root.scriptOpen
    triggerMode: root.pinned ? "click" : "hover"
    contentWidth: popup.fittedContentWidth(Style.space(600))
    contentHeight: popup.fittedContentHeight(root.page === "settings" ? settingsPage.implicitHeight : mainView.implicitHeight)

    Flickable {
      anchors.fill: parent
      contentHeight: root.page === "settings" ? settingsPage.implicitHeight : mainView.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: !root.customizing

      MainView {
        id: mainView
        width: parent.width
        pomo: root
        visible: root.page !== "settings"
      }

      SettingsPage {
        id: settingsPage
        width: parent.width
        pomo: root
        visible: root.page === "settings"
      }
    }
  }
}
