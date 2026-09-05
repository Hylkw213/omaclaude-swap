import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Standalone bar widget: shows every cswap-tracked Claude Code account with
// its rate limits, and switches between them with a click. Talks to `cswap`
// directly — no shared usage directory, no dependency on the stock Agents
// widget or its collectors, so both can run side by side.
Panel {
  id: root
  moduleName: "cswap.accounts"
  ipcTarget: "cswap.accounts"
  manageIpc: false

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string pluginDir: home + "/.config/omarchy/plugins/cswap.accounts"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var accounts: []
  property string loadError: ""
  property bool switchingAccount: false
  property string switchingTarget: ""
  property string switchError: ""

  // Countdowns read this instead of Date.now() so the panel keeps telling
  // the truth while it sits open.
  property double nowMs: Date.now()

  readonly property var activeAccount: {
    for (var i = 0; i < accounts.length; i++)
      if (accounts[i] && accounts[i].active) return accounts[i]
    return null
  }

  readonly property real headlinePercent: {
    if (!activeAccount) return -1
    return Math.max(Number(activeAccount.sessionPercent || 0), Number(activeAccount.weeklyPercent || 0))
  }
  readonly property bool alarming: headlinePercent >= 0.9

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function resetMsFor(iso) {
    if (!iso) return -1
    var ms = new Date(iso).getTime()
    return isFinite(ms) ? ms - root.nowMs : -1
  }

  function formatDuration(ms) {
    if (!(ms > 0)) return "now"
    var minutes = Math.floor(ms / 60000)
    var hours = Math.floor(minutes / 60)
    var days = Math.floor(hours / 24)
    if (days > 0) return days + "d " + (hours % 24) + "h"
    if (hours > 0) return hours + "h " + (minutes % 60) + "m"
    return Math.max(1, minutes) + "m"
  }

  function refreshNow() {
    if (!listProcess.running) listProcess.running = true
  }

  function switchAccount(target) {
    if (switchProcess.running) return
    switchError = ""
    switchingTarget = String(target)
    switchProcess.command = ["bash", root.pluginDir + "/bin/cswap-switch", String(target)]
    switchProcess.running = true
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  property int refreshIntervalSec: Math.max(30, Number(setting("refreshIntervalSec", 300)))

  visible: accounts.length > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: listProcess
    running: false
    command: ["python3", root.pluginDir + "/bin/cswap-roster"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyRoster(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("cswap.accounts", text.trim())
    }
  }

  function applyRoster(output) {
    try {
      var parsed = JSON.parse(String(output || "{}"))
      root.accounts = Array.isArray(parsed.accounts) ? parsed.accounts : []
      root.loadError = parsed.error ? String(parsed.error) : ""
    } catch (e) {
      root.loadError = "Failed to read cswap accounts"
      root.accounts = []
    }
  }

  Process {
    id: switchProcess
    running: false
    property bool ok: false
    onRunningChanged: root.switchingAccount = running
    onExited: function(exitCode) {
      switchProcess.ok = exitCode === 0
      root.switchError = exitCode === 0 ? "" : "Account switch failed"
      root.switchingTarget = ""
      root.refreshNow()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("cswap.accounts/switch", text.trim())
    }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshNow()
  }

  // Cheap enough to keep running: it only re-evaluates text bindings, and a
  // stale "resets in 2h" on a panel that is open is worse than a timer.
  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  onOpenedChanged: if (opened) {
    nowMs = Date.now()
    if (panelFlick) panelFlick.contentY = 0
    refreshNow()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refreshNow(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰓥"
    active: root.alarming
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refreshNow()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(480))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dy !== 0)
          panelFlick.contentY = root.clamp(panelFlick.contentY + dy * Style.space(56), 0,
                                           Math.max(0, panelFlick.contentHeight - panelFlick.height))
      }
      onActivateRequested: root.refreshNow()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") root.refreshNow() }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          // ---------- Hero: mark · active account ----------
          PanelHero {
            id: hero
            visible: !!root.activeAccount
            width: parent.width
            title: "Claude Code"
            meta: root.activeAccount ? root.activeAccount.email : ""
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Item {
                id: heroMark
                width: Style.font.display
                height: Style.font.display

                Image {
                  id: heroMarkImage
                  anchors.fill: parent
                  source: Qt.resolvedUrl("assets/claude.svg")
                  sourceSize.width: Style.font.display * 2
                  sourceSize.height: Style.font.display * 2
                  fillMode: Image.PreserveAspectFit
                }

                Text {
                  anchors.centerIn: parent
                  visible: heroMarkImage.status !== Image.Ready
                  text: button.text
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }
              }
            }
          }

          Text {
            visible: root.accounts.length === 0
            width: parent.width
            topPadding: Style.space(24)
            text: root.loadError !== "" ? root.loadError : "No cswap accounts found.\nRun `cswap add` in a terminal first."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          // ---------- Accounts ----------
          PanelSeparator {
            visible: accountsSection.visible
            foreground: root.foreground
          }

          Column {
            id: accountsSection
            visible: root.accounts.length > 0
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "ACCOUNTS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: root.switchError !== ""
              width: parent.width
              text: root.switchError
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Repeater {
              model: root.accounts

              AccountRow {
                required property var modelData
                width: accountsSection.width
                account: modelData
              }
            }
          }
        }
      }
    }
  }

  // One row per cswap-tracked account: email, org, and both rate-limit
  // windows at a glance. Clicking an inactive row switches to it; the
  // active row is picked out with a check and a border instead of a click
  // target, since switching to the account you're already on is a no-op.
  component AccountRow: Item {
    id: accountRow
    property var account: null

    readonly property bool active: !!account && account.active === true
    readonly property bool busy: !!account && root.switchingAccount
      && String(root.switchingTarget) === String(account.number)
    readonly property bool clickable: !!account && !active && !root.switchingAccount

    implicitHeight: rowContent.implicitHeight + Style.spacing.md * 2

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: accountRow.active ? root.alpha(root.foreground, 0.08) : root.alpha(root.foreground, 0.03)
      border.width: accountRow.active ? 1 : 0
      border.color: root.alpha(root.foreground, 0.3)
    }

    MouseArea {
      anchors.fill: parent
      enabled: accountRow.clickable
      hoverEnabled: accountRow.clickable
      cursorShape: accountRow.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.switchAccount(accountRow.account.number)
    }

    Column {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.spacing.md
      spacing: Style.space(6)

      Text {
        width: parent.width
        text: (accountRow.active ? "✓ " : "") + (accountRow.busy ? "Switching…" : (accountRow.account ? accountRow.account.email : ""))
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: accountRow.active
        elide: Text.ElideRight
      }

      Text {
        readonly property string org: accountRow.account ? String(accountRow.account.organizationName || "") : ""
        visible: text !== ""
        width: parent.width
        text: org + (accountRow.active ? (org !== "" ? " · Selected" : "Selected") : "")
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Row {
        width: parent.width
        spacing: Style.spacing.md

        readonly property real halfWidth: (width - spacing) / 2

        Column {
          width: parent.halfWidth
          spacing: Style.space(4)

          Text {
            readonly property real pct: accountRow.account ? Number(accountRow.account.sessionPercent) : -1
            text: "5h · " + (pct >= 0 ? Math.round(pct * 100) + "%" : "—")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Meter {
            width: parent.width
            value: accountRow.account ? Number(accountRow.account.sessionPercent) : -1
            alarming: accountRow.account && Number(accountRow.account.sessionPercent) >= 0.9
          }

          Text {
            readonly property real ms: accountRow.account ? root.resetMsFor(accountRow.account.sessionResetsAt) : -1
            visible: ms > 0
            text: "Resets in " + root.formatDuration(ms)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Column {
          width: parent.halfWidth
          spacing: Style.space(4)

          Text {
            readonly property real pct: accountRow.account ? Number(accountRow.account.weeklyPercent) : -1
            text: "7d · " + (pct >= 0 ? Math.round(pct * 100) + "%" : "—")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Meter {
            width: parent.width
            value: accountRow.account ? Number(accountRow.account.weeklyPercent) : -1
            alarming: accountRow.account && Number(accountRow.account.weeklyPercent) >= 0.9
          }

          Text {
            readonly property real ms: accountRow.account ? root.resetMsFor(accountRow.account.weeklyResetsAt) : -1
            visible: ms > 0
            text: "Resets in " + root.formatDuration(ms)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  // Rounded track showing the percentage of the allowance used.
  component Meter: Item {
    id: meter
    property real value: -1
    property bool alarming: false
    property real thickness: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

    implicitHeight: thickness

    Rectangle {
      id: meterTrack
      anchors.fill: parent
      radius: height / 2
      color: root.track
    }

    Rectangle {
      anchors.left: meterTrack.left
      anchors.verticalCenter: meterTrack.verticalCenter
      height: meterTrack.height
      radius: meterTrack.radius
      width: meterTrack.width * root.clamp(meter.value, 0, 1)
      color: meter.alarming ? root.urgent : root.foreground

      Behavior on width {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
    }
  }
}
