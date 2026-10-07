import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "einarnot.bibleverse"

  property var enVerses: []
  property var langVerses: []
  property var languageMeta: []
  property string pluginVersion: ""
  property date now: new Date()
  readonly property date today: new Date(now.getFullYear(), now.getMonth(), now.getDate())
  readonly property string userId: Quickshell.env("USER") || Quickshell.env("USERNAME") || "local"
  readonly property string resolvedVersion: Model.versionFromRegistry(root.bar, root.moduleName) || pluginVersion
  // Language: explicit `language` bar setting wins ("auto" follows the system locale).
  // Anything unsupported falls back to English (see Model.resolveLanguage).
  readonly property string systemLocale: Qt.locale().name || Quickshell.env("LANG") || Quickshell.env("LANGUAGE") || "en-GB"
  readonly property string configuredLanguage: setting("language", "auto")
  readonly property string requestedLanguage: configuredLanguage === "auto" ? systemLocale : configuredLanguage
  readonly property string language: Model.resolveLanguage(requestedLanguage)
  readonly property string versesFileName: Model.versesFileForLanguage(language)
  readonly property var activeVerses: Model.selectVerses(enVerses, langVerses, language)
  readonly property string activeLanguage: Model.activeLanguage(enVerses, langVerses, language)
  // Rotation: bar, panel and wallpaper share one schedule (Model.verseForInterval),
  // so they always show the same verse for the current slot.
  readonly property int intervalMinutes: Model.clampInterval(setting("intervalMinutes", Model.DEFAULT_INTERVAL_MINUTES))
  readonly property bool wallpaperEnabled: Model.parseBool(setting("wallpaper", true), true)
  readonly property string wallpaperPosition: Model.positionEntry(setting("position", Model.DEFAULT_POSITION)).value
  readonly property real backgroundOpacity: Model.clampOpacity(setting("backgroundOpacity", Model.DEFAULT_BACKGROUND_OPACITY))
  readonly property var verse: Model.verseForInterval(activeVerses, now, userId, intervalMinutes)
  readonly property string configuredFormat: setting("format", "short")
  readonly property string referenceLabel: Model.barLabel(verse, configuredFormat) || ""
  // The bar label carries the verse itself plus its reference, not just the
  // citation — the citation alone told you nothing about the words. The centre
  // cluster grows rightward, so the verse is cut on a word boundary to a budget
  // that keeps it clear of the right-hand cluster; the tooltip, panel and
  // wallpaper card still carry the full text.
  readonly property int barVerseBudget: 48
  readonly property string displayText: (verse && verse.text
    ? excerpt(String(verse.text), barVerseBudget) + " — " + referenceLabel
    : referenceLabel) || "Bible"
  // Vertical bar slots are narrow; keep those lines to the citation only.
  readonly property var verticalLines: Model.verticalLines(referenceLabel)
  readonly property string copyText: Model.copyPayload(verse, activeLanguage, languageMeta)

  function excerpt(text, limit) {
    var t = String(text || "").trim()
    if (t.length <= limit) return t
    var cut = t.slice(0, limit)
    var space = cut.lastIndexOf(" ")
    if (space >= Math.floor(limit / 2)) cut = cut.slice(0, space)
    return cut.replace(/[.!?,;:]+$/, "") + "…"
  }

  function refresh() {
    now = new Date()
    versesFileEn.reload()
    versesFileLang.reload()
    languagesFile.reload()
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function copyVerse() {
    if (!copyText) return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(copyText) + " | wl-copy"])
    Quickshell.execDetached(["omarchy-notification-send", "-g", "󰂺", "Copied " + (verse ? verse.reference : "verse")])
  }

  // Merge `patch` into this widget's inline shell.json entry. The wallpaper
  // service reads the same entry, so this is the single source of truth for
  // language, rotation and wallpaper placement.
  function persistSettings(patch) {
    var nextSettings = {}
    var currentSettings = root.settings || {}
    for (var key in currentSettings) nextSettings[key] = currentSettings[key]
    for (var patchKey in patch) nextSettings[patchKey] = patch[patchKey]
    root.settings = nextSettings
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, nextSettings)
    return true
  }

  function persistLanguage(value) {
    return persistSettings({ language: String(value || "auto") })
  }

  function persistInterval(value) {
    return persistSettings({ intervalMinutes: Model.clampInterval(value) })
  }

  function persistPosition(value) {
    return persistSettings({ position: Model.positionEntry(value).value })
  }

  function persistWallpaper(value) {
    return persistSettings({ wallpaper: Model.parseBool(value, true) })
  }

  function persistOpacity(value) {
    return persistSettings({ backgroundOpacity: Model.clampOpacity(value) })
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("enVerses" in target) target.enVerses = root.enVerses
    if ("langVerses" in target) target.langVerses = root.langVerses
    if ("languageMeta" in target) target.languageMeta = root.languageMeta
    if ("languageSetting" in target) target.languageSetting = root.configuredLanguage
    if ("persistLanguage" in target) target.persistLanguage = root.persistLanguage
    if ("verses" in target) target.verses = root.activeVerses
    if ("language" in target) target.language = root.language
    if ("userId" in target) target.userId = root.userId
    if ("intervalMinutes" in target) target.intervalMinutes = root.intervalMinutes
    if ("wallpaperEnabled" in target) target.wallpaperEnabled = root.wallpaperEnabled
    if ("position" in target) target.position = root.wallpaperPosition
    if ("backgroundOpacity" in target) target.backgroundOpacity = root.backgroundOpacity
    if ("persistInterval" in target) target.persistInterval = root.persistInterval
    if ("persistPosition" in target) target.persistPosition = root.persistPosition
    if ("persistWallpaper" in target) target.persistWallpaper = root.persistWallpaper
    if ("persistOpacity" in target) target.persistOpacity = root.persistOpacity
    if ("pluginVersion" in target) target.pluginVersion = root.resolvedVersion
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onEnVersesChanged: injectPanel()
  onLangVersesChanged: injectPanel()
  onLanguageMetaChanged: injectPanel()
  onActiveVersesChanged: injectPanel()
  onLanguageChanged: {
    // Drop the previous language until its file loads, so the widget
    // falls back to English instead of showing a stale verse.
    root.langVerses = []
    versesFileLang.reload()
    injectPanel()
  }
  onTodayChanged: injectPanel()
  onVerseChanged: injectPanel()
  onPluginVersionChanged: injectPanel()
  onResolvedVersionChanged: injectPanel()

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
    onDateChanged: root.now = date
  }

  FileView {
    id: versesFileEn
    path: Model.fileUrlToPath(Qt.resolvedUrl("verses/en-GB.json"))
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.enVerses = Model.parseVerses(text())
    onLoadFailed: root.enVerses = []
  }

  FileView {
    id: versesFileLang
    path: Model.fileUrlToPath(Qt.resolvedUrl(root.versesFileName))
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.langVerses = Model.parseVerses(text())
    onLoadFailed: root.langVerses = []
  }

  FileView {
    id: languagesFile
    path: Model.fileUrlToPath(Qt.resolvedUrl("verses/languages.json"))
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.languageMeta = Model.parseVerses(text())
    onLoadFailed: root.languageMeta = []
  }

  FileView {
    id: manifestFile
    path: Model.fileUrlToPath(Qt.resolvedUrl("manifest.json"))
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.pluginVersion = Model.parseManifestVersion(text())
    onLoadFailed: root.pluginVersion = ""
  }

  Component.onCompleted: Qt.callLater(function() {
    versesFileEn.reload()
    versesFileLang.reload()
    languagesFile.reload()
    manifestFile.reload()
    root.injectPanel()
  })

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "einarnot.bibleverse"

    function refresh(): void { root.broadcast("refresh") }
    function copy(): void { root.copyVerse() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.displayText
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: root.verse ? root.verse.text : "Daily Bible verse"

    onPressed: function(b) {
      if (b === Qt.RightButton) root.copyVerse()
      else if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3 ? button.fontSize * 0.9 : button.fontSize
          color: button.foreground
        }
      }
    }
  }
}
