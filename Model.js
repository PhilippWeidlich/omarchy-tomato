.pragma library
// Reine Logik für das Pomodoro-Plugin. Als .pragma library einmal pro
// Shell-Prozess geteilt: alle Leisten-Instanzen (eine pro Monitor) sehen
// dieselben Variablen, darüber wird ein "Leader" bestimmt, der als einziger
// automatische Schreibvorgänge (Ablauf, Verlauf, Nicht-stören) macht.

var instances = []

function register(obj) {
  if (instances.indexOf(obj) < 0) instances.push(obj)
}

function unregister(obj) {
  var i = instances.indexOf(obj)
  if (i >= 0) instances.splice(i, 1)
}

function isLeader(obj) {
  return instances.length > 0 && instances[0] === obj
}

// Pro Phasen-Ende genau einmal handeln (Schlüssel = endMs).
var handledEnds = {}
function claimEnd(endMs) {
  var key = String(endMs)
  if (handledEnds[key]) return false
  handledEnds[key] = true
  return true
}

// ---------- Einstellungen ----------

function copy(o) { return JSON.parse(JSON.stringify(o)) }

var DEFAULTS = {
  // Grundfunktionen
  work: 25,               // Minuten Fokus (klassisch nach Cirillo)
  shortBreak: 5,          // kurze Pause
  longBreak: 15,          // lange Pause
  interval: 4,            // lange Pause nach so vielen Fokus-Sessions
  dailyGoal: 8,           // Sessions pro Tag
  notify: true,           // Meldung oben rechts
  language: "auto",       // "auto" = wie Omarchy, sonst "de" / "en"
  tileStyle: "neutral",   // aktive Kacheln: "neutral" (hell) oder "red" (rot leuchtend)
  // Extras: muss man selbst einschalten
  autoBreak: false,       // Pause nach Fokus automatisch starten
  autoWork: false,        // Fokus nach Pause automatisch starten
  focusDnd: false,        // während Fokus "Nicht stören" einschalten
  sound: false,           // Signalton am Ende einer Phase
  soundName: "bell",      // welcher Ton
  fullscreenBreak: false, // Pause als Vollbild über allen Monitoren
  replayMissed: false,    // stumme Meldungen in der Pause zusammenfassen
  muteAudio: false,       // während Fokus Ton stumm
  stayAwake: false,       // während Fokus kein Bildschirmschoner / keine Sperre
  boxes: null             // linkes/rechtes Feld der Karte (siehe DEFAULT_BOXES)
}

// ---------- Kacheln ----------
// Jede Kachel ist ein Schalter (Einstellung gleichen Namens).
var TILES = [
  { id: "notify",          glyph: "\u{F009A}" },
  { id: "focusDnd",        glyph: "\u{F009B}" },
  { id: "replayMissed",    glyph: "\u{F02DA}" },
  { id: "muteAudio",       glyph: "\u{F075F}" },
  { id: "stayAwake",       glyph: "\u{F0176}" },
  { id: "sound",           glyph: "\u{F057E}" },
  { id: "autoBreak",       glyph: "\u{F03E4}" },
  { id: "autoWork",        glyph: "\u{F040A}" },
  { id: "fullscreenBreak", glyph: "\u{F0293}" }
]

// Was ein Feld zeigen kann
var BOX_MODES = ["tiles", "timer", "stats", "calendar"]
var BOX_MODE_GLYPHS = { tiles: "\u{F0570}", timer: "\u{F051B}", stats: "\u{F0127}", calendar: "\u{F00F0}" }

var DEFAULT_BOXES = {
  left:  { mode: "tiles", size: 2, slots: ["notify", "focusDnd", null, null, null, null, null, null, null] },
  right: { mode: "tiles", size: 2, slots: ["stayAwake", null, null, null, null, null, null, null, null] }
}

function tile(id) {
  for (var i = 0; i < TILES.length; i++) if (TILES[i].id === id) return TILES[i]
  return null
}

function sanitizeBox(raw, fallback, seen) {
  var b = { mode: fallback.mode, size: fallback.size, slots: [null, null, null, null, null, null, null, null, null] }
  if (!raw || typeof raw !== "object") raw = fallback
  if (BOX_MODES.indexOf(raw.mode) >= 0) b.mode = raw.mode
  b.size = raw.size === 3 ? 3 : 2
  var src = Array.isArray(raw.slots) ? raw.slots : []
  for (var i = 0; i < 9; i++) {
    var id = src[i]
    if (i < b.size * b.size && tile(id) && !seen[id]) { b.slots[i] = id; seen[id] = true }
  }
  return b
}

function sanitizeBoxes(raw) {
  var src = raw && typeof raw === "object" ? raw : DEFAULT_BOXES
  var seen = {}
  return { left: sanitizeBox(src.left, DEFAULT_BOXES.left, seen),
           right: sanitizeBox(src.right, DEFAULT_BOXES.right, seen) }
}

function placedTiles(boxes) {
  var used = {}
  var sides = ["left", "right"]
  for (var s = 0; s < 2; s++) {
    var b = boxes && boxes[sides[s]]
    if (!b || b.mode !== "tiles") continue
    for (var i = 0; i < b.size * b.size; i++) if (b.slots[i]) used[b.slots[i]] = true
  }
  return used
}

function unusedTiles(boxes) {
  var used = placedTiles(boxes)
  return TILES.filter(function(t) { return !used[t.id] })
}

// Kachel an (side, index) legen. from: { side, index } oder null (aus dem Baukasten).
// Liegt dort schon eine, tauscht sie den Platz (oder geht zurück in den Baukasten).
function placeTile(boxes, id, side, index, from) {
  var b = copy(boxes)
  if (from && b[from.side]) b[from.side].slots[from.index] = null
  else {
    // auch woanders entfernen, falls doppelt
    ["left", "right"].forEach(function(sd) {
      for (var i = 0; i < 9; i++) if (b[sd].slots[i] === id) b[sd].slots[i] = null
    })
  }
  var occupant = b[side].slots[index]
  b[side].slots[index] = id
  if (occupant && occupant !== id && from && b[from.side]) b[from.side].slots[from.index] = occupant
  return b
}

function removeTile(boxes, id) {
  var b = copy(boxes)
  ;["left", "right"].forEach(function(sd) {
    for (var i = 0; i < 9; i++) if (b[sd].slots[i] === id) b[sd].slots[i] = null
  })
  return b
}

// Größe 2 <-> 3; beim Verkleinern rücken Kacheln nach vorn, Überzählige gehen zurück.
function resizeBox(boxes, side) {
  var b = copy(boxes)
  var box = b[side]
  var tiles = []
  for (var i = 0; i < box.size * box.size; i++) if (box.slots[i]) tiles.push(box.slots[i])
  box.size = box.size === 2 ? 3 : 2
  box.slots = [null, null, null, null, null, null, null, null, null]
  if (box.size === 3) {
    // Positionen im 2x2 auf das 3x3 übertragen (Zeile/Spalte bleiben)
    var old = boxes[side]
    for (var j = 0; j < 4; j++) if (old.slots[j]) box.slots[Math.floor(j / 2) * 3 + j % 2] = old.slots[j]
  } else {
    for (var k = 0; k < Math.min(4, tiles.length); k++) box.slots[k] = tiles[k]
  }
  return b
}

function cycleBoxMode(boxes, side) {
  var b = copy(boxes)
  var i = BOX_MODES.indexOf(b[side].mode)
  b[side].mode = BOX_MODES[(i + 1) % BOX_MODES.length]
  return b
}

var LANGUAGES = ["auto", "de", "en"]

var SOUNDS = ["bell", "message", "message-new-instant"]

function soundPath(name) {
  return "/usr/share/sounds/freedesktop/stereo/" + (SOUNDS.indexOf(name) >= 0 ? name : "bell") + ".oga"
}

var LIMITS = {
  work: [1, 180], shortBreak: [1, 60], longBreak: [1, 120], interval: [1, 12], dailyGoal: [1, 30]
}

function clampInt(v, lo, hi, fallback) {
  var n = Math.round(Number(v))
  if (!isFinite(n)) return fallback
  return Math.max(lo, Math.min(hi, n))
}

function sanitizeSettings(raw) {
  var src = raw && typeof raw === "object" ? raw : {}
  var out = {}
  for (var k in DEFAULTS) {
    if (LIMITS[k]) out[k] = clampInt(src[k], LIMITS[k][0], LIMITS[k][1], DEFAULTS[k])
    else if (k === "boxes") out[k] = sanitizeBoxes(src[k])
    else if (k === "tileStyle") out[k] = src[k] === "red" ? "red" : "neutral"
    else if (k === "language") out[k] = LANGUAGES.indexOf(src[k]) >= 0 ? src[k] : "auto"
    else if (k === "soundName") out[k] = SOUNDS.indexOf(src[k]) >= 0 ? src[k] : DEFAULTS[k]
    else out[k] = typeof src[k] === "boolean" ? src[k] : DEFAULTS[k]
  }
  return out
}

// ---------- Zustand ----------

var PHASES = ["work", "short", "long"]
var STATUSES = ["idle", "running", "paused", "done"]

function emptyState() {
  return { phase: "work", status: "idle", startMs: 0, endMs: 0, plannedMs: 0,
           remainingMs: 0, pausedMs: 0, pauseAt: 0, cycle: 0, cycleDay: "", dndOwned: false, dndSession: 0, muteSession: 0, overlayDismissed: 0 }
}

function num(v) {
  var n = Number(v)
  return isFinite(n) && n >= 0 && n < 1e14 ? n : 0
}

function sanitizeState(raw) {
  var s = emptyState()
  if (!raw || typeof raw !== "object") return s
  if (PHASES.indexOf(raw.phase) >= 0) s.phase = raw.phase
  if (STATUSES.indexOf(raw.status) >= 0) s.status = raw.status
  s.startMs = num(raw.startMs)
  s.endMs = num(raw.endMs)
  s.plannedMs = num(raw.plannedMs)
  s.remainingMs = num(raw.remainingMs)
  s.pausedMs = num(raw.pausedMs)
  s.pauseAt = num(raw.pauseAt)
  s.cycle = clampInt(raw.cycle, 0, 999, 0)
  s.cycleDay = typeof raw.cycleDay === "string" && /^\d{4}-\d\d-\d\d$/.test(raw.cycleDay) ? raw.cycleDay : ""
  s.dndOwned = raw.dndOwned === true
  s.dndSession = num(raw.dndSession)
  s.overlayDismissed = num(raw.overlayDismissed)
  s.muteSession = num(raw.muteSession)
  if ((s.status === "running" && s.endMs <= 0) || (s.status === "paused" && s.remainingMs <= 0)) s.status = "idle"
  return s
}


function phaseMinutes(settings, phase) {
  return phase === "short" ? settings.shortBreak : phase === "long" ? settings.longBreak : settings.work
}

// ---------- Verlauf ----------
// Eintrag: { id, start, end, focusSec, plannedSec, status: "done" | "aborted" }

var MAX_ENTRIES = 50000

function sanitizeHistory(raw) {
  var list = Array.isArray(raw) ? raw : (raw && Array.isArray(raw.entries) ? raw.entries : [])
  var out = []
  var seen = {}
  for (var i = 0; i < list.length && out.length < MAX_ENTRIES; i++) {
    var e = list[i]
    if (!e || typeof e !== "object") continue
    var start = num(e.start), end = num(e.end)
    if (start <= 0 || end < start) continue
    var id = String(e.id || start).slice(0, 32)
    if (seen[id]) continue
    seen[id] = true
    out.push({
      id: id,
      start: start,
      end: end,
      focusSec: clampInt(e.focusSec, 0, 86400, 0),
      plannedSec: clampInt(e.plannedSec, 0, 86400, 0),
      status: e.status === "aborted" ? "aborted" : "done"
    })
  }
  out.sort(function(a, b) { return a.start - b.start })
  return out
}

function pad(n) { return n < 10 ? "0" + n : "" + n }

function dayKey(ms) {
  var d = new Date(ms)
  return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
}

function keyToDate(key) {
  var p = key.split("-")
  return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]))
}

function clockText(sec) {
  sec = Math.max(0, Math.round(sec))
  var h = Math.floor(sec / 3600)
  var m = Math.floor((sec % 3600) / 60)
  var s = sec % 60
  return (h > 0 ? h + ":" + pad(m) : pad(m)) + ":" + pad(s)
}

// Tageswerte: { "2026-11-23": { done, aborted, focusSec } }
function byDay(history) {
  var map = {}
  for (var i = 0; i < history.length; i++) {
    var e = history[i]
    var k = dayKey(e.start)
    if (!map[k]) map[k] = { done: 0, aborted: 0, focusSec: 0 }
    if (e.status === "done") map[k].done++
    else map[k].aborted++
    map[k].focusSec += e.focusSec
  }
  return map
}

function entriesForDay(history, key) {
  var out = []
  for (var i = 0; i < history.length; i++)
    if (dayKey(history[i].start) === key) out.push(history[i])
  return out
}

function sumRange(days, fromDate, toDate) {
  var res = { done: 0, focusSec: 0 }
  var d = new Date(fromDate.getFullYear(), fromDate.getMonth(), fromDate.getDate())
  while (d <= toDate) {
    var v = days[dayKey(d.getTime())]
    if (v) { res.done += v.done; res.focusSec += v.focusSec }
    d.setDate(d.getDate() + 1)
  }
  return res
}

function summary(history, nowMs) {
  var days = byDay(history)
  var now = new Date(nowMs)
  var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  var weekStart = new Date(today)
  weekStart.setDate(today.getDate() - ((today.getDay() + 6) % 7)) // Montag
  var monthStart = new Date(today.getFullYear(), today.getMonth(), 1)

  var total = { done: 0, focusSec: 0 }
  for (var k in days) { total.done += days[k].done; total.focusSec += days[k].focusSec }

  // Serie: Tage in Folge mit mindestens einer fertigen Session (heute darf noch fehlen)
  var streak = 0
  var d = new Date(today)
  if (!(days[dayKey(d.getTime())] && days[dayKey(d.getTime())].done > 0)) d.setDate(d.getDate() - 1)
  while (days[dayKey(d.getTime())] && days[dayKey(d.getTime())].done > 0) {
    streak++
    d.setDate(d.getDate() - 1)
  }

  var t = days[dayKey(today.getTime())] || { done: 0, aborted: 0, focusSec: 0 }
  return {
    today: { done: t.done, aborted: t.aborted, focusSec: t.focusSec },
    week: sumRange(days, weekStart, today),
    month: sumRange(days, monthStart, today),
    total: total,
    streak: streak
  }
}

// 6x7 Raster ab Montag für Monat (year, month0)
function monthGrid(history, year, month0, nowMs) {
  var days = byDay(history)
  var first = new Date(year, month0, 1)
  var offset = (first.getDay() + 6) % 7
  var start = new Date(year, month0, 1 - offset)
  var todayKey = dayKey(nowMs)
  var cells = []
  var maxDone = 0
  for (var i = 0; i < 42; i++) {
    var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
    var key = dayKey(d.getTime())
    var v = days[key] || { done: 0, aborted: 0, focusSec: 0 }
    if (v.done > maxDone) maxDone = v.done
    cells.push({ key: key, day: d.getDate(), inMonth: d.getMonth() === month0,
                 isToday: key === todayKey, done: v.done, aborted: v.aborted, focusSec: v.focusSec })
  }
  for (var j = 0; j < cells.length; j++) cells[j].level = maxDone > 0 ? cells[j].done / maxDone : 0
  return cells
}
