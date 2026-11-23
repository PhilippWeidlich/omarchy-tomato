import QtQuick
import Quickshell.Io
import qs.Commons as Commons

// Übersetzungen des Plugins. language: "auto" folgt der Omarchy-Sprache,
// sonst fest ("de", "en", …). Fehlt ein Text, greift Englisch, dann der Schlüssel.
QtObject {
  id: root
  property var directory: ""
  property string choice: "auto"

  readonly property string language: choice && choice !== "auto" ? choice : String(Commons.I18n.language || "en")
  readonly property string baseLanguage: language.split("-")[0]
  readonly property string dir: String(directory).replace(/^file:\/\//, "").replace(/\/+$/, "")

  readonly property var english: parse(enFile.text())
  readonly property var local: parse(localFile.text())

  function parse(raw) {
    try {
      var v = JSON.parse(raw || "{}")
      return v && typeof v === "object" && !Array.isArray(v) ? v : {}
    } catch (e) { return {} }
  }

  function lookup(key) {
    if (local[key] !== undefined) return local[key]
    if (english[key] !== undefined) return english[key]
    return undefined
  }

  function t(key) {
    var v = lookup(key)
    if (typeof v === "string") return v
    if (v && typeof v === "object") return String(v.other || v.one || key)
    return key
  }

  // Plural: "one" bei genau 1, sonst "other" (reicht für Deutsch und Englisch)
  function tn(key, count) {
    var v = lookup(key)
    if (typeof v === "string") return v
    if (v && typeof v === "object") return String((Number(count) === 1 && v.one !== undefined) ? v.one : (v.other || v.one || key))
    return key
  }

  property FileView enFile: FileView { path: root.dir + "/en.json"; printErrors: false }
  property FileView localFile: FileView {
    path: root.baseLanguage === "en" ? "" : root.dir + "/" + root.baseLanguage + ".json"
    printErrors: false
  }
}
